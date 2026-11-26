// combine_psar.nf

process COMBINE_PSAR{

    label 'SN_nf_combine_psar'

    publishDir "${params.psar_lib}", mode: 'copy'

    input:
    val SPEC_BIN               // First input: path to Spectronaut binary
    val LICENSE                // Second input: license key
    path FASTA
    // The stage-3 .psar files passed in, staged into their own folder so -sad reads exactly these
    // (not the shared publish folder, which also held the stage-1 files and so counted every run twice)
    path stage3_psars, stageAs: 'stage3_psars/*'
    val EXT_PSAR
    val PROP_DIA

    output:
    path "${params.JOB_NAME}.kit", emit: psar_lib

    script:
    """
	# Run-count checks (bin/check_run_count.sh): stop (or warn, RUN_COUNT_ACTION) on a mismatch when EXPECTED_RUNS is set
	check_run_count.sh "COMBINE_PSAR input: stage-3 .psar files" \$(find -L stage3_psars -maxdepth 1 -name '*.psar' | wc -l) "${params.EXPECTED_RUNS ?: ''}" "${params.RUN_COUNT_ACTION}"

	dotnet ${SPEC_BIN} activate ${LICENSE}

	dotnet ${SPEC_BIN} lg -se Pulsar\
        -setTemp ${params.tmp_dir}\
	-sad stage3_psars\
	-k ${params.JOB_NAME}\
        -o ${params.lib_output}\
        -n ${params.JOB_NAME}\
        -fasta ${FASTA}\
        ${EXT_PSAR ? " -sa ${EXT_PSAR}" : ""}\
        ${params.PROP_SEARCH ? " -es ${params.PROP_SEARCH}" : ""}\
        ${PROP_DIA ? "-rs ${PROP_DIA}" : ""}

	# Spectronaut writes this library's summary to a new <time>_<JOB_NAME> folder in lib_output
	out=\$(ls -td ${params.lib_output}/*_${params.JOB_NAME}/ | head -1)
	check_run_count.sh "COMBINE_PSAR used (Number of Raw Files)" \
	    "\$(awk -F'\t' '\$1 == "Number of Raw Files" {print \$2}' "\$out/${params.JOB_NAME}_ResultSummary.txt")" "${params.EXPECTED_RUNS ?: ''}" "${params.RUN_COUNT_ACTION}"
    """

}
