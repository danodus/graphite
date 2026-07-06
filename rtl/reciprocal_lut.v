// reciprocal_lut.v
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

// =========================================================================
// Automatically Generated Piecewise Linear Reciprocal LUT
// 
// Mathematical Architecture:
//   Input index (idx) represents a uniform sub-interval slice in the range [1.0, 2.0).
//   Normalized Coordinate Value: x = 1.0 + (idx / 256.0)
// 
// Equations:
//   lut_base(idx)  = round( 2^30 / x )
//   lut_slope(idx) = lut_base(idx) - lut_base(idx + 1)
// =========================================================================

module reciprocal_lut (
    input  wire        clk,        // Synchronous BRAM clock
    input  wire        stall,      // Stall input (from reciprocal_lerp)
    input  wire [7:0]  idx,        // 8-bit normalization interval index
    output reg  [31:0] base,       // 32-bit segment base anchor point
    output reg  [23:0] slope       // 24-bit linear downward correction scale factor
);

    // Inferred Block RAM Look-Up Table Structure
    always @(posedge clk) if (!stall) begin
        case (idx)
            8'h00: begin base <= 32'h40000000; slope <= 24'h3FC040; end
            8'h01: begin base <= 32'h3FC03FC0; slope <= 24'h3F41BC; end
            8'h02: begin base <= 32'h3F80FE04; slope <= 24'h3EC4B0; end
            8'h03: begin base <= 32'h3F423954; slope <= 24'h3E4915; end
            8'h04: begin base <= 32'h3F03F03F; slope <= 24'h3DCEE6; end
            8'h05: begin base <= 32'h3EC62159; slope <= 24'h3D561C; end
            8'h06: begin base <= 32'h3E88CB3D; slope <= 24'h3CDEB5; end
            8'h07: begin base <= 32'h3E4BEC88; slope <= 24'h3C68A7; end
            8'h08: begin base <= 32'h3E0F83E1; slope <= 24'h3BF3F0; end
            8'h09: begin base <= 32'h3DD38FF1; slope <= 24'h3B808B; end
            8'h0A: begin base <= 32'h3D980F66; slope <= 24'h3B0E71; end
            8'h0B: begin base <= 32'h3D5D00F5; slope <= 24'h3A9D9D; end
            8'h0C: begin base <= 32'h3D226358; slope <= 24'h3A2E0D; end
            8'h0D: begin base <= 32'h3CE8354B; slope <= 24'h39BFB9; end
            8'h0E: begin base <= 32'h3CAE7592; slope <= 24'h39529E; end
            8'h0F: begin base <= 32'h3C7522F4; slope <= 24'h38E6B8; end
            8'h10: begin base <= 32'h3C3C3C3C; slope <= 24'h387C00; end
            8'h11: begin base <= 32'h3C03C03C; slope <= 24'h381274; end
            8'h12: begin base <= 32'h3BCBADC8; slope <= 24'h37AA0F; end
            8'h13: begin base <= 32'h3B9403B9; slope <= 24'h3742CC; end
            8'h14: begin base <= 32'h3B5CC0ED; slope <= 24'h36DCA7; end
            8'h15: begin base <= 32'h3B25E446; slope <= 24'h36779D; end
            8'h16: begin base <= 32'h3AEF6CA9; slope <= 24'h3613A8; end
            8'h17: begin base <= 32'h3AB95901; slope <= 24'h35B0C6; end
            8'h18: begin base <= 32'h3A83A83B; slope <= 24'h354EF3; end
            8'h19: begin base <= 32'h3A4E5948; slope <= 24'h34EE29; end
            8'h1A: begin base <= 32'h3A196B1F; slope <= 24'h348E66; end
            8'h1B: begin base <= 32'h39E4DCB9; slope <= 24'h342FA7; end
            8'h1C: begin base <= 32'h39B0AD12; slope <= 24'h33D1E6; end
            8'h1D: begin base <= 32'h397CDB2C; slope <= 24'h337521; end
            8'h1E: begin base <= 32'h3949660B; slope <= 24'h331955; end
            8'h1F: begin base <= 32'h39164CB6; slope <= 24'h32BE7D; end
            8'h20: begin base <= 32'h38E38E39; slope <= 24'h326497; end
            8'h21: begin base <= 32'h38B129A2; slope <= 24'h320B9E; end
            8'h22: begin base <= 32'h387F1E04; slope <= 24'h31B392; end
            8'h23: begin base <= 32'h384D6A72; slope <= 24'h315C6B; end
            8'h24: begin base <= 32'h381C0E07; slope <= 24'h31062A; end
            8'h25: begin base <= 32'h37EB07DD; slope <= 24'h30B0CA; end
            8'h26: begin base <= 32'h37BA5713; slope <= 24'h305C48; end
            8'h27: begin base <= 32'h3789FACB; slope <= 24'h3008A1; end
            8'h28: begin base <= 32'h3759F22A; slope <= 24'h2FB5D4; end
            8'h29: begin base <= 32'h372A3C56; slope <= 24'h2F63DA; end
            8'h2A: begin base <= 32'h36FAD87C; slope <= 24'h2F12B5; end
            8'h2B: begin base <= 32'h36CBC5C7; slope <= 24'h2EC25D; end
            8'h2C: begin base <= 32'h369D036A; slope <= 24'h2E72D4; end
            8'h2D: begin base <= 32'h366E9096; slope <= 24'h2E2415; end
            8'h2E: begin base <= 32'h36406C81; slope <= 24'h2DD61D; end
            8'h2F: begin base <= 32'h36129664; slope <= 24'h2D88EB; end
            8'h30: begin base <= 32'h35E50D79; slope <= 24'h2D3C7A; end
            8'h31: begin base <= 32'h35B7D0FF; slope <= 24'h2CF0C9; end
            8'h32: begin base <= 32'h358AE036; slope <= 24'h2CA5D7; end
            8'h33: begin base <= 32'h355E3A5F; slope <= 24'h2C5B9E; end
            8'h34: begin base <= 32'h3531DEC1; slope <= 24'h2C121F; end
            8'h35: begin base <= 32'h3505CCA2; slope <= 24'h2BC954; end
            8'h36: begin base <= 32'h34DA034E; slope <= 24'h2B813F; end
            8'h37: begin base <= 32'h34AE820F; slope <= 24'h2B39DA; end
            8'h38: begin base <= 32'h34834835; slope <= 24'h2AF325; end
            8'h39: begin base <= 32'h34585510; slope <= 24'h2AAD1D; end
            8'h3A: begin base <= 32'h342DA7F3; slope <= 24'h2A67BF; end
            8'h3B: begin base <= 32'h34034034; slope <= 24'h2A230A; end
            8'h3C: begin base <= 32'h33D91D2A; slope <= 24'h29DEFB; end
            8'h3D: begin base <= 32'h33AF3E2F; slope <= 24'h299B91; end
            8'h3E: begin base <= 32'h3385A29E; slope <= 24'h2958C9; end
            8'h3F: begin base <= 32'h335C49D5; slope <= 24'h2916A2; end
            8'h40: begin base <= 32'h33333333; slope <= 24'h28D518; end
            8'h41: begin base <= 32'h330A5E1B; slope <= 24'h28942B; end
            8'h42: begin base <= 32'h32E1C9F0; slope <= 24'h2853D8; end
            8'h43: begin base <= 32'h32B97618; slope <= 24'h28141E; end
            8'h44: begin base <= 32'h329161FA; slope <= 24'h27D4FB; end
            8'h45: begin base <= 32'h32698CFF; slope <= 24'h27966B; end
            8'h46: begin base <= 32'h3241F694; slope <= 24'h275870; end
            8'h47: begin base <= 32'h321A9E24; slope <= 24'h271B05; end
            8'h48: begin base <= 32'h31F3831F; slope <= 24'h26DE29; end
            8'h49: begin base <= 32'h31CCA4F6; slope <= 24'h26A1DC; end
            8'h4A: begin base <= 32'h31A6031A; slope <= 24'h266619; end
            8'h4B: begin base <= 32'h317F9D01; slope <= 24'h262AE2; end
            8'h4C: begin base <= 32'h3159721F; slope <= 24'h25F033; end
            8'h4D: begin base <= 32'h313381EC; slope <= 24'h25B60B; end
            8'h4E: begin base <= 32'h310DCBE1; slope <= 24'h257C67; end
            8'h4F: begin base <= 32'h30E84F7A; slope <= 24'h254349; end
            8'h50: begin base <= 32'h30C30C31; slope <= 24'h250AAC; end
            8'h51: begin base <= 32'h309E0185; slope <= 24'h24D290; end
            8'h52: begin base <= 32'h30792EF5; slope <= 24'h249AF2; end
            8'h53: begin base <= 32'h30549403; slope <= 24'h2463D3; end
            8'h54: begin base <= 32'h30303030; slope <= 24'h242D2F; end
            8'h55: begin base <= 32'h300C0301; slope <= 24'h23F707; end
            8'h56: begin base <= 32'h2FE80BFA; slope <= 24'h23C157; end
            8'h57: begin base <= 32'h2FC44AA3; slope <= 24'h238C20; end
            8'h58: begin base <= 32'h2FA0BE83; slope <= 24'h23575F; end
            8'h59: begin base <= 32'h2F7D6724; slope <= 24'h232312; end
            8'h5A: begin base <= 32'h2F5A4412; slope <= 24'h22EF3B; end
            8'h5B: begin base <= 32'h2F3754D7; slope <= 24'h22BBD4; end
            8'h5C: begin base <= 32'h2F149903; slope <= 24'h2288E0; end
            8'h5D: begin base <= 32'h2EF21023; slope <= 24'h22565B; end
            8'h5E: begin base <= 32'h2ECFB9C8; slope <= 24'h222444; end
            8'h5F: begin base <= 32'h2EAD9584; slope <= 24'h21F29B; end
            8'h60: begin base <= 32'h2E8BA2E9; slope <= 24'h21C15E; end
            8'h61: begin base <= 32'h2E69E18B; slope <= 24'h21908C; end
            8'h62: begin base <= 32'h2E4850FF; slope <= 24'h216024; end
            8'h63: begin base <= 32'h2E26F0DB; slope <= 24'h213023; end
            8'h64: begin base <= 32'h2E05C0B8; slope <= 24'h21008A; end
            8'h65: begin base <= 32'h2DE4C02E; slope <= 24'h20D157; end
            8'h66: begin base <= 32'h2DC3EED7; slope <= 24'h20A28A; end
            8'h67: begin base <= 32'h2DA34C4D; slope <= 24'h20741F; end
            8'h68: begin base <= 32'h2D82D82E; slope <= 24'h204619; end
            8'h69: begin base <= 32'h2D629215; slope <= 24'h201872; end
            8'h6A: begin base <= 32'h2D4279A3; slope <= 24'h1FEB2E; end
            8'h6B: begin base <= 32'h2D228E75; slope <= 24'h1FBE48; end
            8'h6C: begin base <= 32'h2D02D02D; slope <= 24'h1F91C1; end
            8'h6D: begin base <= 32'h2CE33E6C; slope <= 24'h1F6597; end
            8'h6E: begin base <= 32'h2CC3D8D5; slope <= 24'h1F39CB; end
            8'h6F: begin base <= 32'h2CA49F0A; slope <= 24'h1F0E58; end
            8'h70: begin base <= 32'h2C8590B2; slope <= 24'h1EE341; end
            8'h71: begin base <= 32'h2C66AD71; slope <= 24'h1EB883; end
            8'h72: begin base <= 32'h2C47F4EE; slope <= 24'h1E8E1E; end
            8'h73: begin base <= 32'h2C2966D0; slope <= 24'h1E640F; end
            8'h74: begin base <= 32'h2C0B02C1; slope <= 24'h1E3A59; end
            8'h75: begin base <= 32'h2BECC868; slope <= 24'h1E10F6; end
            8'h76: begin base <= 32'h2BCEB772; slope <= 24'h1DE7EA; end
            8'h77: begin base <= 32'h2BB0CF88; slope <= 24'h1DBF31; end
            8'h78: begin base <= 32'h2B931057; slope <= 24'h1D96CA; end
            8'h79: begin base <= 32'h2B75798D; slope <= 24'h1D6EB7; end
            8'h7A: begin base <= 32'h2B580AD6; slope <= 24'h1D46F4; end
            8'h7B: begin base <= 32'h2B3AC3E2; slope <= 24'h1D1F81; end
            8'h7C: begin base <= 32'h2B1DA461; slope <= 24'h1CF85E; end
            8'h7D: begin base <= 32'h2B00AC03; slope <= 24'h1CD18A; end
            8'h7E: begin base <= 32'h2AE3DA79; slope <= 24'h1CAB04; end
            8'h7F: begin base <= 32'h2AC72F75; slope <= 24'h1C84CA; end
            8'h80: begin base <= 32'h2AAAAAAB; slope <= 24'h1C5EDE; end
            8'h81: begin base <= 32'h2A8E4BCD; slope <= 24'h1C393B; end
            8'h82: begin base <= 32'h2A721292; slope <= 24'h1C13E5; end
            8'h83: begin base <= 32'h2A55FEAD; slope <= 24'h1BEED7; end
            8'h84: begin base <= 32'h2A3A0FD6; slope <= 24'h1BCA14; end
            8'h85: begin base <= 32'h2A1E45C2; slope <= 24'h1BA598; end
            8'h86: begin base <= 32'h2A02A02A; slope <= 24'h1B8164; end
            8'h87: begin base <= 32'h29E71EC6; slope <= 24'h1B5D78; end
            8'h88: begin base <= 32'h29CBC14E; slope <= 24'h1B39D0; end
            8'h89: begin base <= 32'h29B0877E; slope <= 24'h1B1670; end
            8'h8A: begin base <= 32'h2995710E; slope <= 24'h1AF353; end
            8'h8B: begin base <= 32'h297A7DBB; slope <= 24'h1AD07A; end
            8'h8C: begin base <= 32'h295FAD41; slope <= 24'h1AADE6; end
            8'h8D: begin base <= 32'h2944FF5B; slope <= 24'h1A8B94; end
            8'h8E: begin base <= 32'h292A73C7; slope <= 24'h1A6983; end
            8'h8F: begin base <= 32'h29100A44; slope <= 24'h1A47B5; end
            8'h90: begin base <= 32'h28F5C28F; slope <= 24'h1A2626; end
            8'h91: begin base <= 32'h28DB9C69; slope <= 24'h1A04D9; end
            8'h92: begin base <= 32'h28C19790; slope <= 24'h19E3CA; end
            8'h93: begin base <= 32'h28A7B3C6; slope <= 24'h19C2FB; end
            8'h94: begin base <= 32'h288DF0CB; slope <= 24'h19A26A; end
            8'h95: begin base <= 32'h28744E61; slope <= 24'h198215; end
            8'h96: begin base <= 32'h285ACC4C; slope <= 24'h1961FF; end
            8'h97: begin base <= 32'h28416A4D; slope <= 24'h194225; end
            8'h98: begin base <= 32'h28282828; slope <= 24'h192286; end
            8'h99: begin base <= 32'h280F05A2; slope <= 24'h190323; end
            8'h9A: begin base <= 32'h27F6027F; slope <= 24'h18E3FA; end
            8'h9B: begin base <= 32'h27DD1E85; slope <= 24'h18C50B; end
            8'h9C: begin base <= 32'h27C4597A; slope <= 24'h18A657; end
            8'h9D: begin base <= 32'h27ABB323; slope <= 24'h1887DA; end
            8'h9E: begin base <= 32'h27932B49; slope <= 24'h186997; end
            8'h9F: begin base <= 32'h277AC1B2; slope <= 24'h184B8B; end
            8'hA0: begin base <= 32'h27627627; slope <= 24'h182DB6; end
            8'hA1: begin base <= 32'h274A4871; slope <= 24'h181019; end
            8'hA2: begin base <= 32'h27323858; slope <= 24'h17F2B1; end
            8'hA3: begin base <= 32'h271A45A7; slope <= 24'h17D580; end
            8'hA4: begin base <= 32'h27027027; slope <= 24'h17B883; end
            8'hA5: begin base <= 32'h26EAB7A4; slope <= 24'h179BBC; end
            8'hA6: begin base <= 32'h26D31BE8; slope <= 24'h177F29; end
            8'hA7: begin base <= 32'h26BB9CBF; slope <= 24'h1762C9; end
            8'hA8: begin base <= 32'h26A439F6; slope <= 24'h17469C; end
            8'hA9: begin base <= 32'h268CF35A; slope <= 24'h172AA3; end
            8'hAA: begin base <= 32'h2675C8B7; slope <= 24'h170EDC; end
            8'hAB: begin base <= 32'h265EB9DB; slope <= 24'h16F347; end
            8'hAC: begin base <= 32'h2647C694; slope <= 24'h16D7E2; end
            8'hAD: begin base <= 32'h2630EEB2; slope <= 24'h16BCB0; end
            8'hAE: begin base <= 32'h261A3202; slope <= 24'h16A1AC; end
            8'hAF: begin base <= 32'h26039056; slope <= 24'h1686DB; end
            8'hB0: begin base <= 32'h25ED097B; slope <= 24'h166C37; end
            8'hB1: begin base <= 32'h25D69D44; slope <= 24'h1651C3; end
            8'hB2: begin base <= 32'h25C04B81; slope <= 24'h16377F; end
            8'hB3: begin base <= 32'h25AA1402; slope <= 24'h161D67; end
            8'hB4: begin base <= 32'h2593F69B; slope <= 24'h16037E; end
            8'hB5: begin base <= 32'h257DF31D; slope <= 24'h15E9C3; end
            8'hB6: begin base <= 32'h2568095A; slope <= 24'h15D034; end
            8'hB7: begin base <= 32'h25523926; slope <= 24'h15B6D2; end
            8'hB8: begin base <= 32'h253C8254; slope <= 24'h159D9D; end
            8'hB9: begin base <= 32'h2526E4B7; slope <= 24'h158492; end
            8'hBA: begin base <= 32'h25116025; slope <= 24'h156BB4; end
            8'hBB: begin base <= 32'h24FBF471; slope <= 24'h155300; end
            8'hBC: begin base <= 32'h24E6A171; slope <= 24'h153A77; end
            8'hBD: begin base <= 32'h24D166FA; slope <= 24'h152219; end
            8'hBE: begin base <= 32'h24BC44E1; slope <= 24'h1509E4; end
            8'hBF: begin base <= 32'h24A73AFD; slope <= 24'h14F1D8; end
            8'hC0: begin base <= 32'h24924925; slope <= 24'h14D9F7; end
            8'hC1: begin base <= 32'h247D6F2E; slope <= 24'h14C23D; end
            8'hC2: begin base <= 32'h2468ACF1; slope <= 24'h14AAAC; end
            8'hC3: begin base <= 32'h24540245; slope <= 24'h149343; end
            8'hC4: begin base <= 32'h243F6F02; slope <= 24'h147C01; end
            8'hC5: begin base <= 32'h242AF301; slope <= 24'h1464E8; end
            8'hC6: begin base <= 32'h24168E19; slope <= 24'h144DF5; end
            8'hC7: begin base <= 32'h24024024; slope <= 24'h143728; end
            8'hC8: begin base <= 32'h23EE08FC; slope <= 24'h142083; end
            8'hC9: begin base <= 32'h23D9E879; slope <= 24'h140A03; end
            8'hCA: begin base <= 32'h23C5DE76; slope <= 24'h13F3A8; end
            8'hCB: begin base <= 32'h23B1EACE; slope <= 24'h13DD73; end
            8'hCC: begin base <= 32'h239E0D5B; slope <= 24'h13C763; end
            8'hCD: begin base <= 32'h238A45F8; slope <= 24'h13B177; end
            8'hCE: begin base <= 32'h23769481; slope <= 24'h139BB1; end
            8'hCF: begin base <= 32'h2362F8D0; slope <= 24'h13860E; end
            8'hD0: begin base <= 32'h234F72C2; slope <= 24'h13708E; end
            8'hD1: begin base <= 32'h233C0234; slope <= 24'h135B33; end
            8'hD2: begin base <= 32'h2328A701; slope <= 24'h1345FA; end
            8'hD3: begin base <= 32'h23156107; slope <= 24'h1330E4; end
            8'hD4: begin base <= 32'h23023023; slope <= 24'h131BF1; end
            8'hD5: begin base <= 32'h22EF1432; slope <= 24'h13071F; end
            8'hD6: begin base <= 32'h22DC0D13; slope <= 24'h12F271; end
            8'hD7: begin base <= 32'h22C91AA2; slope <= 24'h12DDE3; end
            8'hD8: begin base <= 32'h22B63CBF; slope <= 24'h12C977; end
            8'hD9: begin base <= 32'h22A37348; slope <= 24'h12B52C; end
            8'hDA: begin base <= 32'h2290BE1C; slope <= 24'h12A102; end
            8'hDB: begin base <= 32'h227E1D1A; slope <= 24'h128CF8; end
            8'hDC: begin base <= 32'h226B9022; slope <= 24'h12790E; end
            8'hDD: begin base <= 32'h22591714; slope <= 24'h126545; end
            8'hDE: begin base <= 32'h2246B1CF; slope <= 24'h12519C; end
            8'hDF: begin base <= 32'h22346033; slope <= 24'h123E11; end
            8'hE0: begin base <= 32'h22222222; slope <= 24'h122AA6; end
            8'hE1: begin base <= 32'h220FF77C; slope <= 24'h12175A; end
            8'hE2: begin base <= 32'h21FDE022; slope <= 24'h12042D; end
            8'hE3: begin base <= 32'h21EBDBF5; slope <= 24'h11F11D; end
            8'hE4: begin base <= 32'h21D9EAD8; slope <= 24'h11DE2D; end
            8'hE5: begin base <= 32'h21C80CAB; slope <= 24'h11CB5A; end
            8'hE6: begin base <= 32'h21B64151; slope <= 24'h11B8A5; end
            8'hE7: begin base <= 32'h21A488AC; slope <= 24'h11A60D; end
            8'hE8: begin base <= 32'h2192E29F; slope <= 24'h119392; end
            8'hE9: begin base <= 32'h21814F0D; slope <= 24'h118135; end
            8'hEA: begin base <= 32'h216FCDD8; slope <= 24'h116EF4; end
            8'hEB: begin base <= 32'h215E5EE4; slope <= 24'h115CCF; end
            8'hEC: begin base <= 32'h214D0215; slope <= 24'h114AC8; end
            8'hED: begin base <= 32'h213BB74D; slope <= 24'h1138DB; end
            8'hEE: begin base <= 32'h212A7E72; slope <= 24'h11270B; end
            8'hEF: begin base <= 32'h21195767; slope <= 24'h111556; end
            8'hF0: begin base <= 32'h21084211; slope <= 24'h1103BE; end
            8'hF1: begin base <= 32'h20F73E53; slope <= 24'h10F23E; end
            8'hF2: begin base <= 32'h20E64C15; slope <= 24'h10E0DC; end
            8'hF3: begin base <= 32'h20D56B39; slope <= 24'h10CF93; end
            8'hF4: begin base <= 32'h20C49BA6; slope <= 24'h10BE65; end
            8'hF5: begin base <= 32'h20B3DD41; slope <= 24'h10AD51; end
            8'hF6: begin base <= 32'h20A32FF0; slope <= 24'h109C58; end
            8'hF7: begin base <= 32'h20929398; slope <= 24'h108B77; end
            8'hF8: begin base <= 32'h20820821; slope <= 24'h107AB2; end
            8'hF9: begin base <= 32'h20718D6F; slope <= 24'h106A05; end
            8'hFA: begin base <= 32'h2061236A; slope <= 24'h105971; end
            8'hFB: begin base <= 32'h2050C9F9; slope <= 24'h1048F7; end
            8'hFC: begin base <= 32'h20408102; slope <= 24'h103895; end
            8'hFD: begin base <= 32'h2030486D; slope <= 24'h10284D; end
            8'hFE: begin base <= 32'h20202020; slope <= 24'h10181C; end
            8'hFF: begin base <= 32'h20100804; slope <= 24'h100804; end
            default: begin base <= 32'h00000000; slope <= 24'h000000; end
        endcase
    end

endmodule
