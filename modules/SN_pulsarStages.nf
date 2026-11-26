// SN_pulsarStages.nf

process PULSAR_1_LIB {

    label 'SN_nf_pulsar'
	// Use publishDir to save the output to the out_lib directory
	publishDir "${params.intermediate_psar}/stage1", mode: 'copy'

    input:
    val SPEC_BIN               // First input: path to Spectronaut binary
    val LICENSE                // Second input: license key
    path FASTA
    val rawfile               // Third input: One rawfile from the raw_d folder
    val PROP_DIA
    val pulsarStep

    output:
    tuple val(rawfile), path("${file(rawfile).getBaseName()}.psar"), emit: psar_with_raw

    // path "${file(rawfile).getBaseName()}.psar", emit: intermediate_psar // Emit the .psar file created for each rawfile

    // Define output and error logs using task variables
    // error = "logs/${task.process}.${task.id}.err"
    // output = "logs/${task.process}.${task.id}.out"

    script:
    """
        echo "Processing rawfile: ${rawfile}"

		dotnet ${SPEC_BIN} activate ${LICENSE}

        dotnet ${SPEC_BIN} lg -se Pulsar\
        -setTemp ${params.tmp_dir}\
       	-r ${rawfile}\
        -o ${params.intermediates_output}\
        -a ${file(rawfile).getBaseName()}\
        -n ${file(rawfile).getBaseName()}\
        -fasta "${FASTA}"\
		${params.PROP_SEARCH ? " -es ${params.PROP_SEARCH}" : ""}\
		${PROP_DIA ? "-rs ${PROP_DIA}" : ""}\
		--pulsarStage ${pulsarStep}
    """
}

process PULSAR_1_LIB_BATCH {

    label 'SN_nf_pulsar'
    // Use publishDir to save the intermediate output to the intermediates directory
    publishDir "${params.intermediate_psar}/stage1", mode: 'copy', pattern: '*.psar'

    input:
    val SPEC_BIN               // First input: path to Spectronaut binary
    val LICENSE                // Second input: license key
    path FASTA
    path rawfiles               // Third input: One rawfile from the raw_d folder
    val PROP_DIA
    val pulsarStep

    output:
    tuple path(rawfiles), path("${task.index}.psar"), emit: psar_with_raw

    // path "${task.index}.psar", emit: intermediate_psar // Emit the intermediate .psar file created for each rawfile

    script:
    """
		echo "Processing rawfile: ${rawfiles}"
		echo "Spectronaut: ${SPEC_BIN}"
		echo "FASTA: ${FASTA}"

		dotnet "${SPEC_BIN}" activate "${LICENSE}"

        dotnet ${SPEC_BIN} lg -se Pulsar\
        -setTemp ${params.tmp_dir}\
        ${rawfiles.collect { "-r ${it}" }.join(' ')}\
        -o ${params.intermediates_output}\
        -a ${task.index}\
		-n ${task.index}\
        -fasta "${FASTA}"\
		${params.PROP_SEARCH ? " -es ${params.PROP_SEARCH}" : ""}\
        ${PROP_DIA ? "-rs ${PROP_DIA}" : ""}\
		--pulsarStage ${pulsarStep}

        echo "Nextflow Task ID: ${task.index}"
    """
}

process GENERATE_QSP{

    label 'SN_nf_combine_psar'
	publishDir "${params.intermediates_output}", mode: 'copy', pattern: '*.qsp'

    input:
    val SPEC_BIN               // First input: path to Spectronaut binary
    val LICENSE                // Second input: license key
    val FASTA
    // The stage-1 .psar files passed in, staged into their own folder so -sad reads exactly these
    // (not the shared publish folder, which also holds stage-3 files)
    path stage1_psars, stageAs: 'stage1_psars/*'
    val PROP_DIA
    val pulsarStep

    output:
    path "${params.JOB_NAME}.qsp", emit: qsp_file

    script:
    """
        # Run-count checks (bin/check_run_count.sh): stop (or warn, RUN_COUNT_ACTION) on a mismatch when EXPECTED_RUNS is set
        check_run_count.sh "GENERATE_QSP input: stage-1 .psar files" \$(find -L stage1_psars -maxdepth 1 -name '*.psar' | wc -l) "${params.EXPECTED_RUNS ?: ''}" "${params.RUN_COUNT_ACTION}"

        dotnet ${SPEC_BIN} activate ${LICENSE}

        dotnet ${SPEC_BIN} lg -se Pulsar\
        -setTemp ${params.tmp_dir}\
        -sad stage1_psars\
        -k ${params.JOB_NAME}\
        -o .\
		--noOutputSubfolder\
        -n ${params.JOB_NAME}\
        -fasta ${FASTA}\
        ${PROP_DIA ? "-rs ${PROP_DIA}" : ""}\
        --pulsarStage ${pulsarStep}

        # Spectronaut can build the QSP from fewer runs than it is given, without a warning; its
        # ResultSummary reports how many it used ("Number of Raw Files")
        check_run_count.sh "GENERATE_QSP used (Number of Raw Files)" \
            "\$(awk -F'\t' '\$1 == "Number of Raw Files" {print \$2}' ${params.JOB_NAME}_ResultSummary.txt)" "${params.EXPECTED_RUNS ?: ''}" "${params.RUN_COUNT_ACTION}"
    """

}

process PULSAR_3_LIB {

    label 'SN_nf_pulsar'
    // Use publishDir to save the output to the out_lib directory
    publishDir "${params.intermediate_psar}/stage3", mode: 'copy'

    input:
    val SPEC_BIN               // First input: path to Spectronaut binary
    val LICENSE                // Second input: license key
    path FASTA
    val PROP_DIA
    val pulsarStep
    tuple path(rawfile), path(psar_file), path(qsp_file)

    output:
    tuple path(rawfile), path("${rawfile.getBaseName()}.psar"), emit: psar_with_raw

    // path "${rawfile.getBaseName()}.psar", emit: intermediate_psar // Emit the .psar file created for each rawfile

    // Define output and error logs using task variables
    // error = "logs/${task.process}.${task.id}.err"
    // output = "logs/${task.process}.${task.id}.out"

    script:
    """
        echo "Processing rawfile: ${rawfile}"

        dotnet ${SPEC_BIN} activate ${LICENSE}

        dotnet ${SPEC_BIN} lg -se Pulsar\
        -setTemp ${params.tmp_dir}\
        -r ${params.rawfile_dir}/${rawfile}\
		-sa ${params.psar_file}\
        -o ${params.intermediates_output}\
        -a ${params.psar_file}\
        -n ${rawfile.getBaseName()}\
        -fasta ${FASTA}\
        ${params.PROP_SEARCH ? " -es ${params.PROP_SEARCH}" : ""}\
        ${PROP_DIA ? "-rs ${PROP_DIA}" : ""}\
		--optimizedModels ${params.intermediates_output}/${qsp_file}\
        --pulsarStage ${pulsarStep}
    """
}

process PULSAR_3_LIB_BATCH {

    label 'SN_nf_pulsar'
    publishDir "${params.intermediate_psar}/stage3", mode: 'copy'

    input:
    val SPEC_BIN
    val LICENSE
    path FASTA
    val PROP_DIA
    val pulsarStep

    // path rawfiles
    tuple path(rawfiles), path(psar_file), path(qsp_file)

    output:
    path "${task.index}.psar", emit: intermediate_psar

    script:
    """
        echo "Spectronaut: ${SPEC_BIN}"
        echo "License: ${LICENSE}"
        echo "FASTA: ${FASTA}"
	echo "Rawfiles: ${rawfiles}"
        echo "PSAR: ${psar_file}"
	echo "QSP: ${qsp_file}"

        dotnet "${SPEC_BIN}" activate ${LICENSE}

        dotnet "${SPEC_BIN}" lg -se Pulsar\
        -setTemp "${params.tmp_dir}"\
        ${rawfiles.collect { "-r \"${params.rawfile_dir}/${it}\"" }.join(' ')}\
        -sa "${psar_file}"\
        -o "${params.intermediates_output}"\
        -a ${task.index}\
        -n ${task.index}\
        -fasta "${FASTA}"\
        ${params.PROP_SEARCH ? " -es ${params.PROP_SEARCH}" : ""}\
        ${PROP_DIA ? "-rs ${PROP_DIA}" : ""}\
        --optimizedModels "${qsp_file}"\
        --pulsarStage ${pulsarStep}

        echo "Nextflow Task ID: ${task.index}"

    """

}
