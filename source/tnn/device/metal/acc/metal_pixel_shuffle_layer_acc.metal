// Tencent is pleased to support the open source community by making TNN available.
//
// Copyright (C) 2020 THL A29 Limited, a Tencent company. All rights reserved.
//
// Licensed under the BSD 3-Clause License (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
//
// https://opensource.org/licenses/BSD-3-Clause
//
// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the 
// specific language governing permissions and limitations under the License.

#include <metal_stdlib>
#include "tnn/device/metal/acc/metal_common.metal"

using namespace metal;
kernel void pixel_shuffle_common(const device ftype4 *src                   [[buffer(0)]],
                                device ftype4 *dst                          [[buffer(1)]],
                                constant MetalPixelShuffleParams& params    [[buffer(2)]],
                                uint3 gid                                   [[thread_position_in_grid]]) {
    if (any(gid >= uint3(params.output_width, params.output_height, params.output_slice*params.batch)))
        return;

    auto index_out = (int)gid.z*params.output_height*params.output_width + (int)gid.y*params.output_width + (int)gid.x;

    int iw    = (int)gid.x / params.upscale_factor;
    int rw    = (int)gid.x % params.upscale_factor;
    int ih    = (int)gid.y / params.upscale_factor;
    int rh    = (int)gid.y % params.upscale_factor;
    int os    = (int)gid.z % params.output_slice;
    int batch = (int)gid.z / params.output_slice;
    int4 oc   = os * 4 + int4(0, 1, 2, 3);

    int4 ic       = ((oc * params.upscale_factor + rh) * params.upscale_factor) + rw;
    int4 is       = ic / 4;
    int4 icr      = ic % 4;
    int4 index_in = ((batch * params.input_slice + is) * params.input_height + ih) * params.input_width + iw;

    bool4 valid_pos = ic < params.input_channel;
    index_in = select(int4(0), index_in, valid_pos);
    icr      = select(int4(0), icr,      valid_pos);

    ftype4 val = select(
        ftype4(0),
        ftype4(
            src[index_in[0]][icr[0]],
            src[index_in[1]][icr[1]],
            src[index_in[2]][icr[2]],
            src[index_in[3]][icr[3]]),
        valid_pos);

    dst[index_out] = val;
}