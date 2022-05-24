/*
    Run ARG screening tools
*/

include { FARGENE                 } from '../../modules/nf-core/modules/fargene/main'
include { DEEPARG_DOWNLOADDATA    } from '../../modules/nf-core/modules/deeparg/downloaddata/main'
include { DEEPARG_PREDICT         } from '../../modules/nf-core/modules/deeparg/predict/main'

include { HAMRONIZATION_DEEPARG   } from '../../modules/nf-core/modules/hamronization/deeparg/main'
include { HAMRONIZATION_SUMMARIZE } from '../../modules/nf-core/modules/hamronization/summarize/main'

workflow ARG {
    take:
    contigs // tuple val(meta), path(contigs)
    annotations // output from prokka

    main:
    ch_versions = Channel.empty()
    ch_mqc      = Channel.empty()

     // Prepare HAMRONIZATION reporting channel
    ch_input_to_hamronization_summarize = Channel.empty()

    // fARGene run
    if ( !params.arg_skip_fargene ) {
        FARGENE ( contigs, params.arg_fargene_hmmmodel )
        ch_versions = ch_versions.mix(FARGENE.out.versions)
    }

    // DeepARG prepare download
    if ( !params.arg_skip_deeparg && params.arg_deeparg_data ) {
        ch_deeparg_db = Channel
            .fromPath( params.arg_deeparg_data )
            .first()
    } else if ( !params.arg_skip_deeparg && !params.arg_deeparg_data ) {
        DEEPARG_DOWNLOADDATA( )
        ch_deeparg_db = DEEPARG_DOWNLOADDATA.out.db
    }

    // DeepARG run

    if ( !params.arg_skip_deeparg ) {

        annotations
                .map {
                    it ->
                        def meta  = it[0]
                        def anno  = it[1]
                        def model = params.arg_deeparg_model

                    [ meta, anno, model ]
                }
                .set { ch_input_for_deeparg }

        DEEPARG_PREDICT ( ch_input_for_deeparg, ch_deeparg_db )
        ch_versions = ch_versions.mix(DEEPARG_PREDICT.out.versions)

    // Reporting
    // Note:currently hardcoding versions
    // how to automate in the future - but DEEPARG won't change as abandonware?
        HAMRONIZATION_DEEPARG ( DEEPARG_PREDICT.out.arg.mix(DEEPARG_PREDICT.out.potential_arg), 'json', '1.0.2', '2'  )
        ch_input_to_hamronization_summarize = ch_input_to_hamronization_summarize.mix(HAMRONIZATION_DEEPARG.out.json)
    }

    ch_input_to_hamronization_summarize
        .map{
            it[1]
        }
        .collect()
        .set { ch_input_for_hamronization_summarize }

    HAMRONIZATION_SUMMARIZE( ch_input_for_hamronization_summarize, params.arg_hamronization_summarizeformat )

    emit:
    versions = ch_versions
    mqc = ch_mqc

}