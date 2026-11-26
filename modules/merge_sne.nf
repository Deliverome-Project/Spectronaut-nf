// merge_sne.nf

process MERGE_SNE {
	
	label 'SN_nf_combine_sne'
	
	//errorStrategy 'retry'
	
	input:
	val SPEC_BIN               // First input: path to Spectronaut binary
	val LICENSE                // Second input: license key
	val sne_files
	val PROP_DIA
	val REPORT
	val COND_SETUP

	// output:
	// path "${params.JOB_NAME}"   // Output directory for each rawfile

	// publishDir "${params.dia_output}", mode: 'copy'
	// cp -r ${params.dia_output}/*/*.sne ${params.dia_output}
	script:
	"""
	# Run-count checks (bin/check_run_count.sh): stop on a mismatch when EXPECTED_RUNS is set.
	# Per-run DIA results are dia_output/<time>_<run>/<time>_<run>.sne; earlier merges (<time>_<JOB_NAME>) are
	# not inputs. A run with two .sne files (e.g. a DIA task that wrote output and was retried) would be merged
	# twice, so count .sne files and distinct runs separately.
	per_run=\$(find ${params.dia_output} -mindepth 2 -maxdepth 2 -name '*.sne' -not -path '*_${params.JOB_NAME}/*')
	check_run_count.sh "MERGE_SNE input: per-run .sne files" \$(printf '%s\n' "\$per_run" | grep -c .) "${params.EXPECTED_RUNS ?: ''}"
	check_run_count.sh "MERGE_SNE input: distinct runs with a .sne" \$(printf '%s\n' "\$per_run" | grep . | xargs -r -n1 basename | sed -E 's/^[0-9]{8}_[0-9]{6}_//' | sort -u | wc -l) "${params.EXPECTED_RUNS ?: ''}"
	if [ -n "${COND_SETUP}" ]; then check_run_count.sh "MERGE_SNE input: condition setup rows" \$(tail -n +2 "${COND_SETUP}" | grep -c .) "${params.EXPECTED_RUNS ?: ''}"; fi

	dotnet ${SPEC_BIN} activate ${LICENSE}

	dotnet ${SPEC_BIN} manageSNE --merge -setTemp ${params.tmp_dir} -d ${params.dia_output} -o ${params.dia_output} -n ${params.JOB_NAME} ${params.PROP_SEARCH ?: ''}\
	${COND_SETUP ? "-con ${COND_SETUP}" : ""} ${REPORT ? "-rs ${REPORT}" : ""} ${PROP_DIA ? "-s ${PROP_DIA}" : ""}

	# The merged experiment lists one row per run in <time>_<JOB_NAME>/<JOB_NAME>_RunIdentifications.tsv
	out=\$(ls -td ${params.dia_output}/*_${params.JOB_NAME}/ | head -1)
	check_run_count.sh "MERGE_SNE used (runs in RunIdentifications)" \$(tail -n +2 "\$out/${params.JOB_NAME}_RunIdentifications.tsv" | grep -c .) "${params.EXPECTED_RUNS ?: ''}"
	"""
}
