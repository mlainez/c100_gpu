// Tiling overrides for YOLOv5s (640x640, f16 with f16 accumulators, im2col
// convolutions, `pascal` preset) on the GM20B. Each thread computes an 8x8
// f16 block, which NAK issues as 8x4 packed HFMA2 pairs, on small
// workgroups; the compiler's f16 defaults use 256-thread workgroups.
// Generated with nx_iree/bench/yolo/family_spec.py:
//   0=400:16,128,32:16,2  1=32:64,32,16:4,8  0=1600:32,128,32:16,4  0=6400:32,128,32:16,4
module attributes {transform.with_named_sequence, iree_codegen.tuning_spec_with_default_entrypoint} {
  transform.named_sequence @apply_op_config(%op: !transform.any_op {transform.readonly}, %config: !transform.any_param {transform.readonly}) {
    transform.annotate %op "compilation_info" = %config : !transform.any_op, !transform.any_param
    transform.yield
  }

  transform.named_sequence @match_0(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 400 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d0, %v0 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[16,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [16,2, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_1(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[1] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 32 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d0, %v0 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[64,32,16]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [4,8, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_2(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 1600 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d0, %v0 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [16,4, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_3(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 6400 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d0, %v0 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [16,4, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @__kernel_config(%variant_op: !transform.any_op {transform.consumed}) -> !transform.any_op
      attributes {iree_codegen.tuning_spec_entrypoint} {
    %res = transform.foreach_match in %variant_op @match_0 -> @apply_op_config, @match_1 -> @apply_op_config, @match_2 -> @apply_op_config, @match_3 -> @apply_op_config : (!transform.any_op) -> !transform.any_op
    transform.yield %res : !transform.any_op
  }
}
