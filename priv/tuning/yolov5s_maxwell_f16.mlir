// Tiling overrides for YOLOv5s on the GM20B: fp16 with f16 accumulators,
// prepared with nx_iree/bench/yolo/prepare.sh and compiled with
// `F16=1 WINOGRAD=1 compile.sh ... pascal`. Rules match ranges of feature-map
// row counts, so the spec holds for any input whose maps divide the tiles
// (640x512: 199 ms, 640x640: 242 ms per frame). Each thread computes an 8x4
// f16 block (8x2 packed HFMA2 pairs) and every family stays at or under
// 128 registers; the pooling rule lays SPPF's first max-pool threads along
// channels so its channels-last reads coalesce.
// Generated with nx_iree/bench/yolo/family_spec.py:
//   "0<=600:16,128,32:32,2" "1=32:64,32,16:8,8"
//   "0>600,0<=3000,1=256:32,128,32:32,4" "0>3000,0<=12000,1=256:32,128,32:32,4"
//   "0>600,0<=3000:32,128,32:16,4" "0>3000,0<=12000:32,128,32:16,4"
//   "g:0=256,1<=32,2<=32:8,1,4,0,0/1,1,1,0,0:4,1,8"
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
      %v0 = transform.param.constant 600 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d0, %v0 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[16,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [32,2, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
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
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [8,8, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
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
      %v0 = transform.param.constant 600 : i64 -> !transform.param<i64>
      transform.match.param.cmpi gt %d0, %v0 : !transform.param<i64>
      %d1 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v1 = transform.param.constant 3000 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d1, %v1 : !transform.param<i64>
      %d2 = transform.match.structured.dim %arg[1] : (!transform.any_op) -> !transform.param<i64>
      %v2 = transform.param.constant 256 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d2, %v2 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [32,4, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
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
      %v0 = transform.param.constant 3000 : i64 -> !transform.param<i64>
      transform.match.param.cmpi gt %d0, %v0 : !transform.param<i64>
      %d1 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v1 = transform.param.constant 12000 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d1, %v1 : !transform.param<i64>
      %d2 = transform.match.structured.dim %arg[1] : (!transform.any_op) -> !transform.param<i64>
      %v2 = transform.param.constant 256 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d2, %v2 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [32,4, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_4(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 600 : i64 -> !transform.param<i64>
      transform.match.param.cmpi gt %d0, %v0 : !transform.param<i64>
      %d1 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v1 = transform.param.constant 3000 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d1, %v1 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [16,4, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_5(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      transform.match.structured.classify_contraction_dims %arg : (!transform.any_op) -> (!transform.param<i64>, !transform.param<i64>, !transform.param<i64>, !transform.param<i64>)
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 3 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 3000 : i64 -> !transform.param<i64>
      transform.match.param.cmpi gt %d0, %v0 : !transform.param<i64>
      %d1 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v1 = transform.param.constant 12000 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d1, %v1 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32,128,32]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<MatmulPromoteVectorize> workgroup_size = [16,4, 1], {pipeline_depth = 1 : i64, store_stage = 1 : i64}>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @match_6(%op: !transform.any_op {transform.readonly}) -> (!transform.any_op, !transform.any_param) {
    %c = transform.match.structured failures(propagate) %op : (!transform.any_op) -> !transform.any_op {
    ^bb0(%arg: !transform.any_op):
      %rank = transform.match.structured.rank %arg : (!transform.any_op) -> !transform.param<i64>
      %r = transform.param.constant 5 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %rank, %r : !transform.param<i64>
      %d0 = transform.match.structured.dim %arg[0] : (!transform.any_op) -> !transform.param<i64>
      %v0 = transform.param.constant 256 : i64 -> !transform.param<i64>
      transform.match.param.cmpi eq %d0, %v0 : !transform.param<i64>
      %d1 = transform.match.structured.dim %arg[1] : (!transform.any_op) -> !transform.param<i64>
      %v1 = transform.param.constant 32 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d1, %v1 : !transform.param<i64>
      %d2 = transform.match.structured.dim %arg[2] : (!transform.any_op) -> !transform.param<i64>
      %v2 = transform.param.constant 32 : i64 -> !transform.param<i64>
      transform.match.param.cmpi le %d2, %v2 : !transform.param<i64>
      transform.match.structured.yield %arg : !transform.any_op
    }
    %config = transform.param.constant #iree_codegen.compilation_info<
      lowering_config = #iree_codegen.lowering_config<tile_sizes = [[8,1,4,0,0], [1,1,1,0,0]]>,
      translation_info = #iree_codegen.translation_info<pipeline = #iree_gpu.spirv_pipeline<BaseVectorize> workgroup_size = [4,1,8]>
    > -> !transform.any_param
    transform.yield %c, %config : !transform.any_op, !transform.any_param
  }

  transform.named_sequence @__kernel_config(%variant_op: !transform.any_op {transform.consumed}) -> !transform.any_op
      attributes {iree_codegen.tuning_spec_entrypoint} {
    %res = transform.foreach_match in %variant_op @match_0 -> @apply_op_config, @match_1 -> @apply_op_config, @match_2 -> @apply_op_config, @match_3 -> @apply_op_config, @match_4 -> @apply_op_config, @match_5 -> @apply_op_config, @match_6 -> @apply_op_config : (!transform.any_op) -> !transform.any_op
    transform.yield %res : !transform.any_op
  }
}
