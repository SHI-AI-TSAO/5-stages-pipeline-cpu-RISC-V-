module cpu #( // Do not modify interface
	parameter ADDR_W = 64,
	parameter INST_W = 32,
	parameter DATA_W = 64
)(
    input                   i_clk,
    input                   i_rst_n,
    input                   i_i_valid_inst, // from instruction memory
    input  [ INST_W-1 : 0 ] i_i_inst,       // from instruction memory
    input                   i_d_valid_data, // from data memory
    input  [ DATA_W-1 : 0 ] i_d_data,       // from data memory
    output                  o_i_valid_addr, // to instruction memory
    output [ ADDR_W-1 : 0 ] o_i_addr,       // to instruction memory
    output [ DATA_W-1 : 0 ] o_d_w_data,     // to data memory
    output [ ADDR_W-1 : 0 ] o_d_w_addr,     // to data memory
    output [ ADDR_W-1 : 0 ] o_d_r_addr,     // to data memory
    output                  o_d_MemRead,    // to data memory
    output                  o_d_MemWrite,   // to data memory
    output                  o_finish
);
// pipeline_used registers
reg [DATA_W-1:0] IFID_r [0:7]; //instruction & PC & PC+4
reg [DATA_W-1:0] IFID_w [0:7];

reg [DATA_W-1:0] IDEX_r [0:8]; //read data1 & read data2 & imm & control & PC& PC+4 & write data & instruction
reg [DATA_W-1:0] IDEX_w [0:8];

reg [DATA_W-1:0] EXMEM_r [0:7]; //ALU Zero & ALU result & read data2 & control & PC & PC+4 & branch address & write data & instruction
reg [DATA_W-1:0] EXMEM_w [0:7];

reg [DATA_W-1:0] MEMC1_r [0:3]; //read data & ALU result & control & write data & instruction
reg [DATA_W-1:0] MEMC1_w [0:3];

reg [DATA_W-1:0] C1WB_r [0:3]; //read data & ALU result & control & write data & instruction
reg [DATA_W-1:0] C1WB_w [0:3];

// other_used registers
reg [63:0] registers_r [0:31];
reg [63:0] registers_w [0:31]; 
reg [63:0] pc_r,pc_w,c_pc_r,c_pc_w;
reg [3:0]  cs,ns;
reg [4:0]  bcs,bns;
reg [6:0]  cycle_r, cycle_w;
reg        load_r,load_w;

// output_used register
reg [ DATA_W-1 : 0 ] o_d_w_data_r, o_d_w_data_w;
reg [ ADDR_W-1 : 0 ] o_d_w_addr_r, o_d_w_addr_w;
reg [ ADDR_W-1 : 0 ] o_d_r_addr_r, o_d_r_addr_w; 
reg                  o_d_MemRead_r, o_d_MemRead_w;
reg                  o_d_MemWrite_r, o_d_MemWrite_w;
reg                  o_i_valid_addr_r, o_i_valid_addr_w;
reg [ ADDR_W-1 : 0 ] o_i_addr_r, o_i_addr_w;
reg                  o_finish_r, o_finish_w;

// output assign 
assign o_d_w_data = o_d_w_data_r;
assign o_d_w_addr = o_d_w_addr_r;
assign o_d_r_addr = o_d_r_addr_r;
assign o_d_MemRead = o_d_MemRead_r;
assign o_d_MemWrite = o_d_MemWrite_r;
assign o_i_valid_addr = o_i_valid_addr_r;
assign o_i_addr = o_i_addr_r;
assign o_finish = o_finish_r;

integer i;
// combinational

always @(*) begin ////!!!!
       case(cs)
	     0: begin
		     //$display("%b %b",(i_i_inst[6:0] == 7'b0000011), (load_r !== 1));
		     if((i_i_inst[6:0] == 7'b0000011) & (load_r !== 1))begin  
			   // $display("load set 1");
	                  ns = 1;
		          load_w = 1;
	             end
		     else if((i_i_inst[6:0] == 7'b1100011) & (load_r !== 1))begin
			   ns = 0;
			   load_w = 1;
		     end
		     else begin
			   ns = 0;
			   if(bcs == 6)
				   load_w = 0;
			   else if(load_r == 1)
				   load_w = 1;
			   else
		               load_w = 0;
		      end
	     end
	     1: begin
		     ns = 2;
		     load_w = 1;
	     end
	     2: begin 
	             ns = 3;
		     load_w = 1;
	     end
	     3: begin
		     ns = 0;
		     load_w = 0;
	     end
             default: begin
		  ns = cs;
		  load_w = load_r;
	     end
       endcase	 
  
       case(bcs) //3 for wait branch result, 3 for wait next instruction out(after branch result is out)
	     0:begin 
	           if((i_i_inst[6:0] == 7'b1100011) & (load_r !== 1))begin
			 bns = 1;
                         load_w = 1;
		   end
		   else if((i_i_inst[6:0] == 7'b0000011) & (load_r !== 1))begin
			  bns = 0;
			  load_w = 1;
		   end
		   else begin
			   bns = 0; 
			   if (cs == 3) 
		                 load_w = 0; // lock on but need to release
			   else if(load_r == 1)
				 load_w = 1; // lock on and keep lock
			   else
                                 load_w = 0; // no lock
		   end

	      end		      
	     1:begin
		     bns=2;
		     load_w = 1;
	     end
	     2:begin
		     bns=3;
		     load_w = 1;
	     end
	     3:begin
		     bns=4;
		     load_w = 1;
	     end
	     4:begin
		     bns=5;
		     load_w = 1;
	     end
	     5:begin
		     bns=6;
		     load_w = 1;
	     end
	     6:begin
		     bns=0;
		     load_w = 0;
	     end
	     default: begin
		     bns =bcs;
	             load_w = load_r;
	     end
       endcase

//end


//always @(*) begin
	//$display("cycle %d",cycle_r);
	//$display("%b",i_i_inst);
	//$display("pc:%d",c_pc_r);
	//$display("load: %d",load_r);
   if (i_i_valid_inst) begin // at first time wait for 3 cycles
	// Determine the Next Instruction
	// Load -> 4 nop
	// branch -> 3 nop
	o_i_valid_addr_w = 1;
	//pc_w <= pc_r + 4;
	//$display("%b",i_i_inst);
        //if(stage == 0) begin
	// IF stage
	//$display("IF stage");
	if (load_r !== 1) begin // not loading
	//$display("Instruction: %b",i_i_inst);
	//c_pc_w = c_pc_r + 4 ;
	IFID_w[0] = i_i_inst;
	IFID_w[1] = c_pc_r;
	IFID_w[2] = c_pc_r + 4;
        IFID_w[3] = registers_r[i_i_inst[19:15]]; //rs1 ;
	IFID_w[4] = registers_r[i_i_inst[24:20]]; //rs2 = registers[i]
	IFID_w[5] = 0; ////!!!!
	IFID_w[6] = 0; ////!!!!
	IFID_w[7] = 0; ////!!!!
	//$display("rs1: %d",registers_r[i_i_inst[19:15]]);
	//$display("rs2: %d",registers_r[i_i_inst[24:20]]);
		case(i_i_inst[6:0])
			7'b0000011: begin //ld
			       //$display("ld");
			       IFID_w[5] = i_i_inst[31:20];
	                       IFID_w[6][0] = 0;
		               IFID_w[6][1] = 1;
			       IFID_w[6][2] = 1;
                               IFID_w[6][4:3] = 2'b00;
			       IFID_w[6][5] = 0;
			       IFID_w[6][6] = 1;
			       IFID_w[6][7] = 1;
			       IFID_w[6][8] = 1;
			       IFID_w[7] = 4'b0000;
		       end
		       7'b0100011: begin //sd
		               //$display("sd");
			       IFID_w[5] = {i_i_inst[31:25],i_i_inst[11:7]};
	                       IFID_w[6][0] = 0;
		               IFID_w[6][1] = 0;
			       IFID_w[6][2] = 0;
                               IFID_w[6][4:3] = 2'b00;
			       IFID_w[6][5] = 1;
			       IFID_w[6][6] = 1;
			       IFID_w[6][7] = 0;
			       IFID_w[6][8] = 0;
			       IFID_w[7] = 4'b0000;
		       end
		       7'b1100011: begin //beq/bne
		               //$display("beq/bne");
			       IFID_w[5][11] = i_i_inst[31];
			       IFID_w[5][10] = i_i_inst[7];
			       IFID_w[5][9:4] = i_i_inst[30:25];
			       IFID_w[5][3:0] = i_i_inst[11:8];
	                       IFID_w[6][0] = 1;
		               IFID_w[6][1] = 0;
			       IFID_w[6][2] = 0;
                               IFID_w[6][4:3] = 2'b01;
			       IFID_w[6][5] = 0;
			       IFID_w[6][6] = 0;
			       IFID_w[6][7] = 0;
			       IFID_w[6][8] = 0; 
			       IFID_w[7] = 4'b1000;//sub //{i_i_inst[30],i_i_inst[14],i_i_inst[13],i_i_inst[12]};
		       end
		       7'b0010011: begin //addi/xori/ori/andi/slli/srli
		               //$display("addi/xori/ori/andi/slli/srli");
			       IFID_w[5] = i_i_inst[31:20]; //imm_value = i_i_inst[31:20];
	                       IFID_w[6][0] = 0;
		               IFID_w[6][1] = 0;
			       IFID_w[6][2] = 0;
                               IFID_w[6][4:3] = 2'b10;
			       IFID_w[6][5] = 0;
			       IFID_w[6][6] = 1;
			       IFID_w[6][7] = 1;
			       IFID_w[6][8] = 1; 
			       IFID_w[7] = {i_i_inst[30],i_i_inst[14],i_i_inst[13],i_i_inst[12]};
		       end
		       7'b0110011: begin //add/sub/xor/or/and
		               //$display("add/sub/xor/or/and");
			       IFID_w[5] = 1'bx;////!!!!
	                       IFID_w[6][0] = 0;
		               IFID_w[6][1] = 0;
			       IFID_w[6][2] = 0;
                               IFID_w[6][4:3] = 2'b10;
			       IFID_w[6][5] = 0;
			       IFID_w[6][6] = 0;
			       IFID_w[6][7] = 1;
			       IFID_w[6][8] = 1; 
			       IFID_w[7] = {i_i_inst[30],i_i_inst[14],i_i_inst[13],i_i_inst[12]};
		       end
		       7'b1111111: begin
			       IFID_w[5] = 0;//1'bx;////!!!!
			       IFID_w[6] = 0;//1'bx;
			       IFID_w[7][3:0] = 4'b1111;//1'bx;////!!!!
		       end
		       default: begin
			       IFID_w[5] = 0;//IFID_r[5];////!!!!
			       IFID_w[6] = 0;//IFID_r[6]; ////!!!!
			       IFID_w[7][3:0] = 4'b1111;//IFID_r[7];////!!!! 
			       //o_finish_w = 0;
		       end
	       endcase         
            end
	    else begin // Insert no operation
		  // $display("Instruction: nop");
		  // $display("original instruction %b",i_i_inst);
		   //c_pc_w = c_pc_r;
		   for (i=0; i<8; i=i+1)
			  IFID_w[i] = 0;//64'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	    end
               /* we don't convert the alu control as textbook
		case(IFID_r[7]) // change to real acontrol
			4'b0000:  
				acontrol_w = 4'b0010; //add
			4'b1000:
				acontrol_w = 4'b0110; //sub
			4'b0111:
				acontrol_w = 4'b0000; //and
			4'b0110:
				acontrol_w = 4'b0001; //or
			4'b0001:
			        acontrol_w = 4'b1111; //slli
			4'b0101:
				acontrol_w = 4'b1110; //srli
			default: begin
				o_finish_w = 0;
			end
		endcase
		*/

	// ID stage
	//$display("ID stage");
	//$display("Instruction: %b",IFID_r[0][31:0]);	
	//$display("rs1: %d",registers_r[IFID_r[0][19:15]]);
	//$display("rs2: %d",registers_r[IFID_r[0][24:20]]);
	IDEX_w[2] = IFID_r[4];
	IDEX_w[3] = IFID_r[6];
	IDEX_w[4] = IFID_r[1];
	IDEX_w[5] = IFID_r[2];
	IDEX_w[6] = IFID_r[0];
	IDEX_w[7] = IFID_r[7];		
	IDEX_w[8] = IFID_r[5];

	 // EX stage
	 //$display("EX stage");
	 //$display("Instruction: %b",IDEX_r[6][31:0]);
	 //$display("rs1: %d",registers_r[IDEX_r[6][19:15]]);  
      	 //$display("rs2: %d",registers_r[IDEX_r[6][24:20]]); 
	//ALU 
		case(IDEX_r[7][3:0]) // alu control
			4'b0000: begin //add
			        o_d_w_addr_w = IDEX_r[0] + IDEX_r[1];
			        o_d_r_addr_w = IDEX_r[0] + IDEX_r[1];
			        EXMEM_w[1] = IDEX_r[0] + IDEX_r[1];
			        //$display("IDEX_r[0] + IDEX_r[1] = %d + %d", IDEX_r[0],IDEX_r[1]);
				//if(IDEX_r[6][6:0]==7'b0100011) 
			        //      $display("Store Address: %h", IDEX_r[0] + IDEX_r[1]);
				//else if (IDEX_r[6][6:0]==7'b0000011) 
				//      $display("Load Address: %h", IDEX_r[0] + IDEX_r[1]);
		         end
			 4'b1000: begin //sub
			    
			 o_d_w_addr_w = o_d_w_addr_r;////!!!!
       			 o_d_r_addr_w = o_d_r_addr_r;////!!!! 
			        EXMEM_w[1] = IDEX_r[0] - IDEX_r[1];
				//$display("IDEX_r[0] - IDEX_r[1] = %d - %d", IDEX_r[0],IDEX_r[1]);
		         end
			 4'b0111: begin //and
			 o_d_w_addr_w = o_d_w_addr_r;////!!!!
			 o_d_r_addr_w = o_d_r_addr_r;////!!!!
			        EXMEM_w[1] = IDEX_r[0] & IDEX_r[1];
				//$display("IDEX_r[0] & IDEX_r[1] = %b & %b = %h", IDEX_r[0],IDEX_r[1],IDEX_r[0] & IDEX_r[1]);
		         end
			 4'b0110: begin //or
			 o_d_w_addr_w = o_d_w_addr_r;////!!!!
         		 o_d_r_addr_w = o_d_r_addr_r;////!!!!
			        EXMEM_w[1] = IDEX_r[0] | IDEX_r[1];
			 //$display("IDEX_r[0] | IDEX_r[1] = %b | %b = %h", IDEX_r[0],IDEX_r[1],IDEX_r[0] | IDEX_r[1]);
		         end
			 4'b0100: begin //xor
			 o_d_w_addr_w = o_d_w_addr_r;////!!!!   
			 o_d_r_addr_w = o_d_r_addr_r;////!!!!
			        EXMEM_w[1] = IDEX_r[0] ^ IDEX_r[1];
				// $display("IDEX_r[0] ^ IDEX_r[1] = %b ^ %b = %h", IDEX_r[0],IDEX_r[1],IDEX_r[0] ^ IDEX_r[1]);
			end
			 4'b0001: begin//slli
				 o_d_w_addr_w = o_d_w_addr_r;////!!!!
				 o_d_r_addr_w = o_d_r_addr_r;////!!!!
			        EXMEM_w[1] = IDEX_r[0] << IDEX_r[1];
				// $display("IDEX_r[0] << IDEX_r[1] = %b << %b = %h", IDEX_r[0],IDEX_r[1],IDEX_r[0] << IDEX_r[1]);
			end
			4'b0101: begin //srli
			o_d_w_addr_w = o_d_w_addr_r;////!!!!    
			o_d_r_addr_w = o_d_r_addr_r;////!!!!
			        EXMEM_w[1] = IDEX_r[0] >> IDEX_r[1];
				// $display("IDEX_r[0] >> IDEX_r[1] = %b >> %b = %h", IDEX_r[0],IDEX_r[1],IDEX_r[0] >> IDEX_r[1]);
			 end
			 default: begin
				 o_d_w_addr_w = o_d_w_addr_r;////!!!!        
				 o_d_r_addr_w = o_d_r_addr_r;////!!!!
				EXMEM_w[1] = 0;//1'bx;
			 end
		endcase

        //Forwarding
	//RS1
	//$display("IFID_r[0][19:15]: %b",IFID_r[0][19:15]);
	//$display("IDEX_r[6][11:7]: %b",IDEX_r[6][11:7]);
	//$display("IDEX_r[3][2]: %b",IDEX_r[3][8]);
	//$display(" ~IDEX_r[3][1]): %b", ~IDEX_r[3][1]);
	if (((IFID_r[0][19:15] == IDEX_r[6][11:7]) && (IDEX_r[3][8]) && ~IDEX_r[3][1])) begin
		//$display("Into RS1 Forwarding");
		case(IDEX_r[7][3:0]) // alu control
			4'b0000: begin //add
                                IDEX_w[0] = IDEX_r[0] + IDEX_r[1];
		         end
			 4'b1000: begin //sub
				IDEX_w[0] = IDEX_r[0] - IDEX_r[1];
		         end
			 4'b0111: begin //and
				IDEX_w[0] = IDEX_r[0] & IDEX_r[1];
		         end
			 4'b0110: begin //or
			        IDEX_w[0] = IDEX_r[0] | IDEX_r[1];
		         end
			 4'b0100: begin//xor
				 IDEX_w[0] = IDEX_r[0] ^ IDEX_r[1]; 
			 end
			 4'b0001: begin//slli
				IDEX_w[0] = IDEX_r[0] << IDEX_r[1];
			end
			4'b0101: begin //srli
				IDEX_w[0] = IDEX_r[0] >> IDEX_r[1];
			 end
			 default: begin
				IDEX_w[0] = IFID_r[3];
			 end
		endcase
	end
        else if ((IFID_r[0][19:15] == EXMEM_r[7][11:7]) && EXMEM_r[3][8]) begin//rs1's register number = EXMEM rd
			 if (EXMEM_r[3][1]) begin // ld : MemRead =1
				 //$display("Forwarding : read data not yet");
			        IDEX_w[0] = 1'bx; ////!!!!
			 end
			 else begin
				 //$display("Forwarding : ALU up value = ALU result");
				 IDEX_w[0] = EXMEM_r[1]; //ALU up value = ALU result
			 end
		 end
         else if ((IFID_r[0][19:15] == MEMC1_r[3][11:7]) && MEMC1_r[2][8]) begin//rs1's register number = MEMC1 rd
			 if (MEMC1_r[2][1]) begin //ld 
				 //$display("Forwarding : read data not yet");
			         IDEX_w[0] = 1'bx; ////!!!!
			 end
			 else begin
				 //$display("Forwarding : ALU up value = ALU result");
				 IDEX_w[0] = MEMC1_r[1]; //ALU up input = ALU result
			 end
		 end
          else if ((IFID_r[0][19:15] == C1WB_r[3][11:7]) && C1WB_r[2][8]) begin//rs1's register number = C1WB rd
			 if (C1WB_r[2][1]) begin //ld  
				 //$display("Forwarding : ALU up value = read data");
				 IDEX_w[0] = i_d_data;//C1WB_r[0];
			 end
			 else begin
				 //$display("Forwarding : ALU up value = ALU result");
				 IDEX_w[0] = C1WB_r[1]; //ALU up input = ALU result
			 end
		 end
	   else  begin//rs1 no forwarding
		    //$display("RS1 no farwarding");
			 IDEX_w[0] = registers_r[IFID_r[0][19:15]];//IFID_r[3]; //ALU up input = rs1
	   end
         //RS2 
	     case(IFID_r[6][6]) //ALUSrc
		     1'b1:
			     IDEX_w[1] = IFID_r[5]; //ALU down input = imm 
		     1'b0: begin 
		     //$display("IFID_r[0][24:20]: %b",IFID_r[0][24:20]);
		     //$display("IDEX_r[6][11:7]: %b %b",IDEX_r[6][11:7],IDEX_r[3][8]);
		     //$display("EXMEM_r[7][11:7]: %b",EXMEM_r[7][11:7],EXMEM_r[3][8]);
		     //$display("MEMC1_r[3][11:7]: %b",MEMC1_r[3][11:7],MEMC1_r[2][8]);
		     //$display("C1WB_r[3][11:7]: %b",C1WB_r[3][11:7], C1WB_r[2][8]);  
	if ((IFID_r[0][24:20] == IDEX_r[6][11:7]) && (IDEX_r[3][8] && ~IDEX_r[3][1])) begin
		case(IDEX_r[7][3:0]) // alu control
			4'b0000: begin //add
                                IDEX_w[1] = IDEX_r[0] + IDEX_r[1];
		         end
			 4'b1000: begin //sub
				IDEX_w[1] = IDEX_r[0] - IDEX_r[1];
		         end
			 4'b0111: begin //and
				IDEX_w[1] = IDEX_r[0] & IDEX_r[1];
		         end
			 4'b0110: begin //or
			        IDEX_w[1] = IDEX_r[0] |IDEX_r[1];
		         end
			 4'b0100: begin//xor
		                IDEX_w[1] = IDEX_r[0] ^ IDEX_r[1];
			 end  
			 4'b0001: begin//slli
				IDEX_w[1] = IDEX_r[0] << IDEX_r[1];
			end
			4'b0101: begin //srli
				IDEX_w[1] = IDEX_r[0] >> IDEX_r[1];
			 end
			 default: begin
				//IDEX_w[1] <= 1'bx;
				IDEX_w[1] =registers_r[IFID_r[0][24:20]];//IFID_r[4];
			 end
		endcase
	end
        else if ((IFID_r[0][24:20] == EXMEM_r[7][11:7]) && EXMEM_r[3][8]) begin//rs2's register number = EXMEM rd
				 if(EXMEM_r[3][1]) begin
				         //$display("Forwarding : read data not yet");
			                 IDEX_w[1] = 1'bx;//?//!!!!
				 end
				 else begin
					// $display("Forwarding : ALU down value = ALU result");
					 IDEX_w[1] = EXMEM_r[1];
				 end
         end
         else if ((IFID_r[0][24:20] == MEMC1_r[3][11:7]) && MEMC1_r[2][8])begin//rs2's register number = EXMEM rd
				 if(MEMC1_r[2][1]) begin
				         //$display("Forwarding : read data not yet");
			                 IDEX_w[1] = 1'bx;//?//!!!!
				 end
				 else begin
					 //$display("Forwarding : ALU down value = ALU result");
					 IDEX_w[1] = MEMC1_r[1];
				 end
	end
        else if ((IFID_r[0][24:20] == C1WB_r[3][11:7]) && C1WB_r[2][8]) begin//rs2's register number = EXMEM rd
				 if(C1WB_r[2][1]) begin
				         //$display("Forwarding : read data ");
			                 IDEX_w[1] =i_d_data;// C1WB_r[0];
				 end
				 else begin
					 //$display("Forwarding : ALU down value = ALU result");
					 IDEX_w[1] = C1WB_r[1];
				 end
         end
	 else begin//rs2 no forwarding
		 //$display("RS2 no forwarding");
			         IDEX_w[1] = registers_r[IFID_r[0][24:20]];//IFID_r[4]; //ALU down input = rs2
	 end
    end
    default:
			      IDEX_w[1] = registers_r[IFID_r[0][24:20]];//IFID_r[4];
    endcase
         
                EXMEM_w[0] = 0;
		EXMEM_w[2] = IDEX_r[1];
                EXMEM_w[3] = IDEX_r[3];
		EXMEM_w[4] = IDEX_r[4];
		EXMEM_w[5] = IDEX_r[5];
		EXMEM_w[7] = IDEX_r[6];
		//i = IDEX_r[2] << 1;
		if(IDEX_r[8][11]) begin //negatine
		        EXMEM_w[6] = IDEX_r[4] -((~({52'b1111111111111111111111111111111111111111111111111111,IDEX_r[8][11:0]}-1)) << 1) ;
		       //if(IDEX_r[3][0])
			        //$display("branch imm:- %b, c_pc: %d",(~({52'b1111111111111111111111111111111111111111111111111111,IDEX_r[8][11:0]}-1)), IDEX_r[4]);
		end
		else begin
			EXMEM_w[6] = ({52'b0000000000000000000000000000000000000000000000000000,IDEX_r[8][11:0]} << 1) + IDEX_r[4];
		       // if(IDEX_r[3][0])
		               // $display("branch imm: %d, c_pc: %d",{52'b0000000000000000000000000000000000000000000000000000,IDEX_r[8][11:0]} , IDEX_r[4]);
		end
                //$display("Instruction: %b", MEMWB_r[3]);
		//$display("control: %b",MEMWB_r[2]);
		//$display("Instruction: %b", EXMEM_r[7]);
	        //$display("control: %b",EXMEM_r[3]);	
	
		// rs2 value forwarding for write data reason
		//if (MEMWB_r[2][2] || EXMEM_r[3][2]) begin
		if(IDEX_r[3][5] === 1) begin
		if (C1WB_r[2][8] || (MEMC1_r[2][8] || EXMEM_r[3][8])) begin
		     if(EXMEM_r[3][8] && (IDEX_r[6][24:20] == EXMEM_r[7][11:7])) begin	
				 if (~EXMEM_r[3][1]) begin //NOT load
			               o_d_w_data_w = EXMEM_r[1]; //ALU RESULT
				      // $display("o_d_w_data_w: %h",EXMEM_r[1]);
			         end 
				 else begin
				       o_d_w_data_w = o_d_w_data_r;////!!!!
				       //$display("DATA NOT YET");
				 end
		      end
		      else if (MEMC1_r[2][8] && (IDEX_r[6][24:20] == MEMC1_r[3][11:7])) begin  
				if (MEMC1_r[2][1]) begin //load
				      // $display("DATA NOT YET");
				     o_d_w_data_w = o_d_w_data_r;////!!!! 
				end
				else begin
					o_d_w_data_w = MEMC1_r[1]; //ALU RESULT 
					//$display("o_d_w_data_w: %h",MEMC1_r[1]); 
				end
			
			end
			else if (C1WB_r[2][8] && (IDEX_r[6][24:20] == C1WB_r[3][11:7])) begin
				if (C1WB_r[2][1]) begin //load
					o_d_w_data_w = i_d_data;//C1WB_r[0]; //READ DATA
					//$display("o_d_w_data_w: %h",i_d_data);
				end
				else begin
					o_d_w_data_w = C1WB_r[1]; //ALU RESULT
			                //$display("o_d_w_data_w: %h", C1WB_r[1]); 
				end
			end	
			else begin
					o_d_w_data_w = registers_r[IDEX_r[6][24:20]];
					//$display("o_d_w_data_w: %h",registers_r[IDEX_r[6][24:20]]);
			end
		end
		else begin
			o_d_w_data_w = registers_r[IDEX_r[6][24:20]];
			//$display("o_d_w_data_w: %d",registers_r[IDEX_r[6][24:20]]);
		end
	        end
		else begin
			o_d_w_data_w = 1'bx;
		end

		//$display("o_d_w_data_w: %d",registers_r[IDEX_r[6][24:20]]);
		//$display("o_d_MemRead_w/o_d_MemWrite_w : %d/%d",IDEX_r[3][1], IDEX_r[3][5]);
		//o_d_w_data_w = IDEX_r[2];
		o_d_MemRead_w = IDEX_r[3][1];
		o_d_MemWrite_w = IDEX_r[3][5];
       
	// MEM stage
	//$display("MEM stage");
	//$display("Instruction: %b",EXMEM_r[7][31:0]);
	//$display("rs1: %d",registers_r[EXMEM_r[7][19:15]]);
	//$display("rs2: %d",registers_r[EXMEM_r[7][24:20]]);  
	if (EXMEM_r[3][0] == 1) begin //branch instruction
		if (EXMEM_r[7][14:12] === 3'b001) begin //bne
			if (EXMEM_r[1] !== 64'b0000000000000000000000000000000000000000000000000000000000000000) begin // not equal
		               //branch actioni
			       //$display("BNE Branch! to %h",EXMEM_r[6]);
			       o_i_addr_w = EXMEM_r[6]; // set branch address
			       pc_w = EXMEM_r[6]; // set next current pc
			       c_pc_w = EXMEM_r[6];
		        end    
			else begin
			       o_i_addr_w = EXMEM_r[5]; // -12 + 4(next)
			       pc_w = EXMEM_r[5];
			       c_pc_w = EXMEM_r[5];
		       end
	        end
		else begin //beq
			if (EXMEM_r[1] === 64'b0000000000000000000000000000000000000000000000000000000000000000) begin
			       //branch action
			       //$display("BEQ Branch! to %h",EXMEM_r[6]);
		               o_i_addr_w = EXMEM_r[6]; // set branch address
			       pc_w = EXMEM_r[6]; // set next current pc
			       c_pc_w = EXMEM_r[6];
		       end 
		       else begin
			       pc_w = EXMEM_r[5];
			       o_i_addr_w = EXMEM_r[5];
			       c_pc_w = EXMEM_r[5];
		       end
	        end
	end
	else if ((i_i_inst[6:0] === 7'b0000011) && (load_r == 0)) begin// load, just cut one time
		pc_w = pc_r - 8;
		if(load_r !== 1)
		        c_pc_w = c_pc_r + 4;////!!!!
	        else
			c_pc_w = c_pc_r;
		o_i_addr_w = pc_r - 8; 
	end
	else begin
		pc_w = pc_r + 4; 
		if(load_r !== 1)
		         c_pc_w = c_pc_r + 4;////!!!!
		else
			c_pc_w = c_pc_r;
		o_i_addr_w = pc_r + 4;
	end
        
        MEMC1_w[0] = i_d_data;// in the stage data haven't read yet 
	MEMC1_w[1] = EXMEM_r[1];
	//if (EXMEM_r[7][6:0] == 7'b0000011)
	//          $display("ld");
	//$display("i_d_valid_data: %b",i_d_valid_data);
	//$display("NOT YET read data %h", i_d_data);
        //$display("alu result %h", EXMEM_r[1]);
        MEMC1_w[2] = EXMEM_r[3];
	MEMC1_w[3] = EXMEM_r[7];

	// C1 stage
	//$display("C1 stage");
	//$display("Instruction: %b",MEMC1_r[3][31:0]);
	C1WB_w[0] = i_d_data;
	C1WB_w[1] = MEMC1_r[1];
	//if (MEMC1_r[3][6:0] == 7'b0000011)
	//	  $display("ld");
	//$display("i_d_valid_data: %b",i_d_valid_data);
        //$display("NOT YET read data %h", i_d_data);
	C1WB_w[2] = MEMC1_r[2];
	C1WB_w[3] = MEMC1_r[3];

        // WB stage
	//$display("WB stage");
	//$display("Instruction: %b",C1WB_r[3][31:0]);
	//$display("i_d_valid_data: %b",i_d_valid_data);
	//$display("AREADY read data %h", i_d_data);
	if(C1WB_r[2][8] == 1) begin //store dnd branch on't go WB
		//$display("register #: %b",C1WB_r[3][11:7]);
		for (i=0;i<32;i=i+1)                
			registers_w[i] = registers_r[i];  
		if (C1WB_r[2][2]) begin//MemtoReg
		       //for (i=0;i<32;i=i+1) begin
			 //      if(i===C1WB_r[3][11:7])
                         registers_w[C1WB_r[3][11:7]] = i_d_data;
			   //    else
			//	      registers_w[i] = registers_r[i];
		     // end
		       //$display("read data to reg: %h", i_d_data);
	        end  
		else begin
		       // for (i=0;i<32;i=i+1) begin
			//	if(i===C1WB_r[3][11:7])
		        registers_w[C1WB_r[3][11:7]] = C1WB_r[1];
			//	else
			//		registers_w[i] = registers_r[i];     
			//end
	               //$display("alu result to reg: %h", C1WB_r[1]); 
	        end
        end
	else begin
		for (i=0;i<32;i=i+1) 
		        registers_w[i] = registers_r[i];////!!!!
	end

	if(C1WB_r[3][31:0] == 32'b11111111111111111111111111111111)
		  o_finish_w = 1;
	else
		  o_finish_w = 0;


	end
	else begin
	     //$display("initial!!!!!");
	    for (i = 0; i<32 ; i = i + 1) 
                  registers_w[i] = 0;
	  
	    for (i=0;i<8;i=i+1)
		    IFID_w[i] = 0;
	    for (i=0;i<9;i=i+1)
		    IDEX_w[i] = 0;
	    for (i=0;i<8;i=i+1)
		    EXMEM_w[i] = 0;
	    for (i=0;i<4;i=i+1)
		    MEMC1_w[i] = 0;
	    for (i=0;i<4;i=i+1)
		    C1WB_w[i] = 0;
	    
             //o_i_valid_addr_w <= 1;
	     //o_i_addr_w <= 0;
		
	// when instruction haven't fetch yet
	//	o_i_addr_w <= pc_r;
         pc_w =  pc_r + 4;
	 o_i_addr_w = pc_r + 4;
	 o_i_valid_addr_w = 1;
	 c_pc_w = 0;
	 o_finish_w = 0;
	 o_d_w_data_w = o_d_w_data_r;
	 o_d_w_addr_w = o_d_w_addr_r;
	 o_d_r_addr_w = o_d_r_addr_r;
	 o_d_MemRead_w = 0;
	 o_d_MemWrite_w = 0;
	//	o_finish_w = 0;
	end
	
	cycle_w = cycle_r + 1;
end


// sequential
always @(posedge i_clk or negedge i_rst_n) begin
	if (~i_rst_n) begin
		 o_d_w_data_r <= 0 ;
		 o_d_w_addr_r <= 0 ;
		 o_d_r_addr_r <= 0 ;
		 o_d_MemRead_r <= 0;
		 o_d_MemWrite_r <= 0;
		 o_i_valid_addr_r <= 1;
		 o_i_addr_r <= 0;
		 o_finish_r <= 0;
		 pc_r <= 0;
		 c_pc_r <= 0;
		 cycle_r <= 0;
		 cs <= 0;
		 bcs <=0;
		 load_r <= 0;
		 for (i = 0; i<32 ; i = i + 1) 
		       registers_r[i] <= 0;
		 for (i=0; i<8; i=i+1)
		       IFID_r[i]    <= 0;
	         for (i=0; i<9; i=i+1)
		       IDEX_r[i]    <= 0;
	         for (i=0; i<8; i=i+1)
		       EXMEM_r[i]   <= 0;
	         for (i=0; i<4; i=i+1)
		       MEMC1_r[i]   <= 0;
	         for (i=0; i<4; i=i+1)
		       C1WB_r[i]   <= 0;
	  end else begin
		  o_d_w_data_r <= o_d_w_data_w ;
		  o_d_w_addr_r <= o_d_w_addr_w ;
		  o_d_r_addr_r <= o_d_r_addr_w ;
		  o_d_MemRead_r <= o_d_MemRead_w;
		  o_d_MemWrite_r <= o_d_MemWrite_w;
		  o_i_valid_addr_r <= o_i_valid_addr_w;
		  o_i_addr_r <= o_i_addr_w;
		  o_finish_r <= o_finish_w;
		  pc_r <= pc_w;
		  c_pc_r <= c_pc_w;
		  cycle_r <= cycle_w;
		  cs <= ns;
		  bcs <= bns;
		  load_r <= load_w;
		  for (i=0; i<32; i=i+1)
		       registers_r[i] <= registers_w[i];
		  for (i=0; i<8; i=i+1)
		       IFID_r[i] <= IFID_w[i];
	          for (i=0; i<9; i=i+1)
		       IDEX_r[i] <= IDEX_w[i];
	          for (i=0; i<8; i=i+1)
		       EXMEM_r[i] <= EXMEM_w[i];
	          for (i=0; i<4; i=i+1)
		       MEMC1_r[i] <= MEMC1_w[i];
	          for (i=0; i<4; i=i+1)
		       C1WB_r[i] <= C1WB_w[i];
	      
	  end
  end

endmodule
