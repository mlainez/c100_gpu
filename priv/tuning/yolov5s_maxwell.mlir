// Tiling overrides for YOLOv5s (640x640, fp32, im2col convolutions) on the
// GM20B. The compiler's defaults for the `turing` preset are kept everywhere
// except for two matmul families where they leave each thread a 2x4 or 4x4
// output block:
//   * M = 400 (the 20x20 feature maps): 16x128x32 tiles on a 32x2 workgroup,
//     an 8x4 block per thread, one warp per workgroup;
//   * N = 32 (the stem, 102400x32x144 after padding the input to four
//     channels): 64x32x16 tiles on an 8x16 workgroup, an 8x4 block per thread.
// Every other family measured slower with the same treatment.
module attributes {transform.with_named_sequence, iree_codegen.tuning_spec_with_default_entrypoint} {
  transform.named_sequence @apply_op_config(%op: !transform.any_op {transform.readonly}, %config: !transform.any_param {transform.readonly}) {
    transform.annotate %op "compilation_info" = %config : !transform.any_op, !transform.any_param
    transform.yield
  }

  transform.named_sequence @match_m400(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %c3 = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %c3 : !transform.param<i64>
      %m = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %c400 = transform.param.constant 400 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %m, %c400 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[16, 128, 32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [32, 2, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_n32(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %c3 = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %c3 : !transform.param<i64>
      %n = transform.match.structured.dim %arg[1] : (!transform.any_op) -> !transform.param<i64>
      %c32 = transform.param.constant 32 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %n, %c32 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[64, 32, 16]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [8, 16, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @__kernel_config(%variant_op: !transform.any_op {transform.consumed}) -> !transform.any_op
      attributes {iree_codegen.tuning_spec_entrypoint} {
    %res = transform.foreach_match in %variant_op @match_m400 -> @apply_op_config, @match_n32 -> @apply_op_config : (!transform.any_op) -> !transform.any_op
    transform.yield %res : !transform.any_op
  }
}
