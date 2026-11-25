#!/usr/bin/env nextflow

// Start Spectronaut-nf at GENERATE_QSP from existing Pulsar stage-1 .psar files.
//
// main.nf always starts at PULSAR_1_LIB. This entry point skips that stage and takes a list of stage-1
// .psar files made earlier (by main.nf, or by the same `lg -se Pulsar --pulsarStage pulsarStep1` call run
// outside Nextflow), then runs the rest of the pipeline unchanged:
//
//   GENERATE_QSP -> PULSAR_3_LIB_BATCH -> COMBINE_PSAR -> WORKFLOW_DIA(_BATCH) -> MERGE_SNE / COMBINE_SNE(_REPORT)
//
// Required in addition to main.nf's parameters:
//   STAGE1_PSAR_LIST  text file, one stage-1 .psar path per line (absolute, or relative to the launch
//                     directory); blank lines and lines starting with '#' are ignored.
//
// Each .psar must come from ONE raw file and be named after it (<run>.psar for <run>.raw), as
// PULSAR_1_LIB (batch_size 1) writes it. The matching raw file must be in rawfile_dir. Only the listed
// runs are searched: the library and the DIA search use exactly these runs, not every raw file in
// rawfile_dir, so a subset (for example one arm of an experiment) can share rawfile_dir with the full set.
// sample_size and excludePattern do not apply; the list decides which runs are used.
//
// Run:  nextflow run /path/to/from_stage1_psar.nf -params-file params.yaml [-c local.config] [-resume]

include { GENERATE_QSP } from './modules/SN_pulsarStages.nf'
include { PULSAR_3_LIB_BATCH } from './modules/SN_pulsarStages.nf'
include { COMBINE_PSAR } from './modules/combine_psar.nf'
include { WORKFLOW_DIA } from './modules/SN_dia.nf'
include { WORKFLOW_DIA_BATCH } from './modules/SN_dia.nf'
include { COMBINE_SNE_REPORT } from './modules/combine_sne.nf'
include { COMBINE_SNE } from './modules/combine_sne.nf'
include { MERGE_SNE } from './modules/merge_sne.nf'

def resolveFilePath(val) {
	if (!val) return null
	def f = file(val)
	return f.exists() ? f.toAbsolutePath().toString() : file("${launchDir}/${val}").toAbsolutePath().toString()
}

workflow {

	// ============================================================
	// Spectronaut executable and license (same rules as main.nf)
	// ============================================================

	def usingContainer = workflow.profile.contains('container')
	if (usingContainer && !params.image_path) {
		exit 1, "ERROR: '-profile container' requires 'image_path' to be set."
	}
	if (!usingContainer && !params.spec_bin) {
		exit 1, "ERROR: running without '-profile container' requires 'spec_bin' to be set."
	}
	def spec_bin = usingContainer ? (params.spec_bin ?: '/usr/lib/spectronaut/SpectronautCMD.dll') : resolveFilePath(params.spec_bin)
	println "Spectronaut executable: ${spec_bin}"

	[params.log_dir, params.intermediates_output, params.lib_output, params.dia_output, params.tmp_dir].each { d ->
		def dir = new File("${d}")
		if (!dir.exists() && !dir.mkdirs()) { error "Could not create directory: ${d}" }
	}

	def license = params.license?.toString()?.trim()
	if (!license) { error "License must be provided in params.yaml" }
	if (new File(license).exists()) {
		def licenseFile = new File(license)
		if (!licenseFile.isFile()) { error "License path exists but is not a file: ${license}" }
		license = licenseFile.readLines()[0]?.trim()
		if (!license) { error "License file is empty: ${licenseFile}" }
		println "License loaded from file: ${licenseFile}"
	} else {
		println "License provided directly as a value"
	}

	def FASTA = resolveFilePath(params.FASTA)
	RANDOM_SLEEP = Channel.value(file("${baseDir}/scripts/random_sleep.sh"))

	def EXT_PSAR   = (params.EXT_PSAR && !params.EXT_PSAR.contains("null")) ? resolveFilePath(params.EXT_PSAR) : ""
	def PROP_DIA   = (params.PROP_DIA && !params.PROP_DIA.contains("null")) ? resolveFilePath(params.PROP_DIA) : ""
	def COND_SETUP = (params.COND_SETUP && !params.COND_SETUP.contains("null")) ? resolveFilePath(params.COND_SETUP) : ""
	def REPORT     = (params.REPORT && !params.REPORT.contains("null")) ? resolveFilePath(params.REPORT) : ""

	// ============================================================
	// Stage-1 .psar list -> (raw file, .psar) pairs, checked before anything runs
	// ============================================================

	if (!params.STAGE1_PSAR_LIST) { error "STAGE1_PSAR_LIST must be set: a text file listing stage-1 .psar files" }
	def listFile = file(resolveFilePath(params.STAGE1_PSAR_LIST))
	if (!listFile.exists()) { error "STAGE1_PSAR_LIST not found: ${listFile}" }

	def psarPaths = listFile.readLines().collect { it.trim() }.findAll { it && !it.startsWith('#') }
		.collect { it.startsWith('/') ? file(it) : file("${launchDir}/${it}") }
	if (!psarPaths) { error "STAGE1_PSAR_LIST has no .psar paths: ${listFile}" }

	def RAW_EXTENSIONS = ['.raw', '.RAW', '.d', '.wiff', '.mzML']
	def problems = []
	def pairs = psarPaths.collect { psar ->
		if (!psar.exists() || psar.size() == 0) { problems << "missing or empty .psar: ${psar}"; return null }
		if (psar.extension != 'psar') { problems << "not a .psar file: ${psar}"; return null }
		def raws = RAW_EXTENSIONS.collect { ext -> file("${params.rawfile_dir}/${psar.baseName}${ext}") }.findAll { it.exists() }
		if (raws.size() != 1) {
			problems << "expected exactly one raw file named ${psar.baseName}.* in ${params.rawfile_dir}, found ${raws.size()}"
			return null
		}
		[raws[0].toAbsolutePath().toString(), psar]
	}
	def dupes = psarPaths.countBy { it.baseName }.findAll { k, v -> v > 1 }.keySet()
	if (dupes) { problems << "runs listed more than once: ${dupes.join(', ')}" }
	if (problems) { error "STAGE1_PSAR_LIST ${listFile}:\n  " + problems.join('\n  ') }

	def nRuns = pairs.size()
	log.info "Starting at GENERATE_QSP from ${nRuns} stage-1 .psar files listed in ${listFile}"
	pairs.each { raw, psar -> log.info "  ${psar.name} <- ${raw}" }

	pulsarStep1_output = Channel.fromList(pairs)
	rawf_mapped_psar = pulsarStep1_output.map { raw, psar -> psar }

	Spectronaut = Channel.value(spec_bin)
	SN_license = Channel.value(license)

	// ============================================================
	// From here on: the same steps as main.nf
	// ============================================================

	qsp_file = GENERATE_QSP(Spectronaut, SN_license, FASTA, rawf_mapped_psar.collect(), PROP_DIA ?: "", "pulsarStep2")
	qsp_file.view { "QSP OUTPUT: $it" }

	pulsar3_input = pulsarStep1_output.combine(qsp_file).map { item -> tuple(item[0], item[1], item[2]) }
	pulsar3_input.view { "PULSAR STEP3 INPUT: $it" }

	pulsarStep3_output = PULSAR_3_LIB_BATCH(Spectronaut, SN_license, FASTA, PROP_DIA ?: "", "pulsarStep3", pulsar3_input)

	kit_file = COMBINE_PSAR(Spectronaut, SN_license, FASTA, pulsarStep3_output.collect(), EXT_PSAR ?: "", PROP_DIA ?: "")
	kit_file.view { "KIT OUTPUT: $it" }
	kit_file_value = kit_file.first()

	// DIA search on the listed runs only
	rawfiles_for_dia = Channel.fromList(pairs.collect { raw, psar -> file(raw) })

	def batchSize = params.batch_size ? params.batch_size.toInteger() : 1
	if (batchSize > 1) {
		def batchSize_dia = batchSize * 2
		log.info "Processing raw files in batches of ${batchSize_dia} for the DIA search"
		dia_output = WORKFLOW_DIA_BATCH(Spectronaut, SN_license, FASTA, kit_file_value,
			rawfiles_for_dia.buffer(size: batchSize_dia, remainder: true), EXT_PSAR ?: "", PROP_DIA ?: "", RANDOM_SLEEP)
	} else {
		log.info "Processing raw files individually (batch size = 1) for the DIA search"
		dia_output = WORKFLOW_DIA(Spectronaut, SN_license, FASTA, kit_file_value, rawfiles_for_dia, EXT_PSAR ?: "", PROP_DIA ?: "", RANDOM_SLEEP)
	}
	dia_output.view { "DIA Output: $it" }

	merged_input = dia_output.collect()

	// main.nf counts every raw file in rawfile_dir here; this entry point counts the listed runs
	if (nRuns > params.max_files_for_ManageSNE && REPORT) {
		log.info "INFO: ${nRuns} runs > ${params.max_files_for_ManageSNE}: CombineSNE with report schema"
		COMBINE_SNE_REPORT(Spectronaut, SN_license, FASTA, merged_input, PROP_DIA, REPORT)
	} else if (nRuns > params.max_files_for_ManageSNE) {
		log.info "INFO: ${nRuns} runs > ${params.max_files_for_ManageSNE}: CombineSNE"
		COMBINE_SNE(Spectronaut, SN_license, FASTA, merged_input, PROP_DIA)
	} else {
		log.info "INFO: Executing ManageSNE to merge all SNEs to a single SNE file"
		MERGE_SNE(Spectronaut, SN_license, merged_input, PROP_DIA ?: "", REPORT ?: "", COND_SETUP ?: "")
	}
}
