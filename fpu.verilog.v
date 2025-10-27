`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.10.2025 14:50:15
// Design Name: 
// Module Name: fpu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// FPU Top-Level Module
// Connects the arithmetic units based on the opcode.
//
module fpu (
    input wire clk,
    input wire rst,
    input wire [3:0] opcode,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    output wire [31:0] result,
    output wire overflow,
    output wire underflow,
    output wire zero_divide
);

    // Opcodes for operations
    parameter OP_ADD = 4'b0001;
    parameter OP_SUB = 4'b0010;
    parameter OP_MUL = 4'b0011;
    parameter OP_DIV = 4'b0100;

    // Wires for submodule outputs
    wire [31:0] add_sub_result;
    wire add_sub_overflow, add_sub_underflow;

    wire [31:0] mul_result;
    wire mul_overflow, mul_underflow;

    wire [31:0] div_result;
    wire div_overflow, div_underflow, div_zero_divide;

    reg [31:0] result_reg;
    reg overflow_reg, underflow_reg, zero_divide_reg;

    // Instantiate the Add/Sub unit
    fp_add_sub add_sub_unit (
        .clk(clk),
        .rst(rst),
        .op_is_sub(opcode == OP_SUB),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(add_sub_result),
        .overflow(add_sub_overflow),
        .underflow(add_sub_underflow)
    );

    // Instantiate the Multiplication unit
    fp_mult mult_unit (
        .clk(clk),
        .rst(rst),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(mul_result),
        .overflow(mul_overflow),
        .underflow(mul_underflow)
    );

    // Instantiate the Division unit
    fp_div div_unit (
        .clk(clk),
        .rst(rst),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(div_result),
        .overflow(div_overflow),
        .underflow(div_underflow),
        .zero_divide(div_zero_divide)
    );

    // Select the result based on the opcode
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result_reg <= 32'b0;
            overflow_reg <= 1'b0;
            underflow_reg <= 1'b0;
            zero_divide_reg <= 1'b0;
        end else begin
            case (opcode)
                OP_ADD: begin
                    result_reg <= add_sub_result;
                    overflow_reg <= add_sub_overflow;
                    underflow_reg <= add_sub_underflow;
                    zero_divide_reg <= 1'b0;
                end
                OP_SUB: begin
                    result_reg <= add_sub_result;
                    overflow_reg <= add_sub_overflow;
                    underflow_reg <= add_sub_underflow;
                    zero_divide_reg <= 1'b0;
                end
                OP_MUL: begin
                    result_reg <= mul_result;
                    overflow_reg <= mul_overflow;
                    underflow_reg <= mul_underflow;
                    zero_divide_reg <= 1'b0;
                end
                OP_DIV: begin
                    result_reg <= div_result;
                    overflow_reg <= div_overflow;
                    underflow_reg <= div_underflow;
                    zero_divide_reg <= div_zero_divide;
                end
                default: begin
                    result_reg <= 32'b0;
                    overflow_reg <= 1'b0;
                    underflow_reg <= 1'b0;
                    zero_divide_reg <= 1'b0;
                end
            endcase
        end
    end
    
    assign result = result_reg;
    assign overflow = overflow_reg;
    assign underflow = underflow_reg;
    assign zero_divide = zero_divide_reg;

endmodule

module fp_add_sub (
    input  wire clk,
    input  wire rst,
    input  wire op_is_sub,            // 1 for subtraction, 0 for addition
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    output reg  [31:0] result,
    output reg  overflow,
    output reg  underflow
);

    // Field decomposition
    wire sign_a = operand_a[31];
    wire [7:0] exp_a = operand_a[30:23];
    wire [22:0] man_a = operand_a[22:0];
    
    wire sign_b = operand_b[31];
    wire [7:0] exp_b = operand_b[30:23];
    wire [22:0] man_b = operand_b[22:0];

 wire [23:0] full_man_a = {1'b1, man_a};
 wire [23:0] full_man_b = {1'b1, man_b};
  
  //reg [7:0]exp_diff;
  reg [23:0]alinged_man_a;
reg [23:0]alinged_man_b;
reg [7:0]result_exp;
wire effective_sign_b;
wire is_add_operation;
reg [24:0]temp_mantissa;
reg temp_sign;
    reg [7:0]  final_exp;
    reg [22:0] final_man;
    reg        final_sign;
    reg [4:0]  shift_amount; // For priority encoder (max shift 23)
    reg        is_zero_result;
    reg        overflow_w;   // Internal wire for overflow
    reg        underflow_w;  // Internal wire for underflow
    reg [24:0] shifted_man_temp;
 assign effective_sign_b = op_is_sub ? ~sign_b : sign_b;
assign is_add_operation = (sign_a == effective_sign_b);
always@(*)
begin
if (exp_a > exp_b)
begin
    // exp_diff =(exp_a-exp_b);
     alinged_man_a=full_man_a;
     alinged_man_b=full_man_b>>(exp_a-exp_b);
     result_exp =exp_a;
 end  
else if(exp_a < exp_b)  
begin
   // exp_diff =(exp_b-exp_a);
    alinged_man_a=full_man_a>>(exp_b-exp_a);
    alinged_man_b=full_man_b;
    result_exp =exp_b;
end 
else
begin
  
   result_exp =exp_a;
   alinged_man_a=full_man_a;
   alinged_man_b=full_man_b;
end
 if(is_add_operation)
   begin
       temp_mantissa={1'b0,alinged_man_a}+{1'b0,alinged_man_b};
       temp_sign=sign_a;
   end
   else
   begin
      if(alinged_man_a>=alinged_man_b)
      begin
      temp_mantissa = {1'b0, alinged_man_a} - {1'b0, alinged_man_b};
          temp_sign=sign_a;
      end
      else 
      begin
          temp_mantissa = {1'b0, alinged_man_b} - {1'b0, alinged_man_a};
          temp_sign= effective_sign_b;
      end
      
   end
   final_sign   = temp_sign;
        final_exp    = result_exp;
        final_man    = 23'd0; // Default
        shift_amount = 5'd0;
        is_zero_result = 1'b0;
        overflow_w   = 1'b0;
        underflow_w  = 1'b0;
// --- CASE 1: Overflow (Shift Right) ---
        if (temp_mantissa[24] == 1'b1) begin
            final_man = temp_mantissa[23:1]; // Optimized
            final_exp = result_exp + 1;
        end
        
        // --- CASE 2: Already Normal ---
        else if (temp_mantissa[23] == 1'b1) begin
            final_man = temp_mantissa[22:0]; // Optimized
            final_exp = result_exp;
        end 
        else begin
                // Priority Encoder: Find first '1' in temp_mantissa[22:0]
                // to determine how much to shift left.
                casez(temp_mantissa[22:0])
                    23'b1??????????????????????: shift_amount = 5'd1;
                    23'b01?????????????????????: shift_amount = 5'd2;
                    23'b001????????????????????: shift_amount = 5'd3;
                    23'b0001???????????????????: shift_amount = 5'd4;
                    23'b00001??????????????????: shift_amount = 5'd5;
                    23'b000001?????????????????: shift_amount = 5'd6;
                    23'b0000001????????????????: shift_amount = 5'd7;
                    23'b00000001???????????????: shift_amount = 5'd8;
                    23'b000000001??????????????: shift_amount = 5'd9;
                    23'b0000000001?????????????: shift_amount = 5'd10;
                    23'b00000000001????????????: shift_amount = 5'd11;
                    23'b000000000001???????????: shift_amount = 5'd12;
                    23'b0000000000001??????????: shift_amount = 5'd13;
                    23'b00000000000001?????????: shift_amount = 5'd14;
                    23'b000000000000001????????: shift_amount = 5'd15;
                    23'b0000000000000001???????: shift_amount = 5'd16;
                    23'b00000000000000001??????: shift_amount = 5'd17;
                    23'b000000000000000001?????: shift_amount = 5'd18;
                    23'b0000000000000000001????: shift_amount = 5'd19;
                    23'b00000000000000000001???: shift_amount = 5'd20;
                    23'b000000000000000000001??: shift_amount = 5'd21;
                    23'b0000000000000000000001?: shift_amount = 5'd22;
                    23'b00000000000000000000001: shift_amount = 5'd23;
                    default:                     shift_amount = 5'd0; // Should be covered by true zero
                endcase
                // Check for Underflow (exponent becomes <= 0)
                if (result_exp <= shift_amount) begin
                    underflow_w = 1'b1;
                    is_zero_result = 1'b1; // Flush to zero (simplest approach)
                end
                else begin
                    // Perform the left shift
                    final_exp = result_exp - shift_amount;
                    // Shift the *entire* 25-bit number
                   shifted_man_temp = temp_mantissa << shift_amount;
                   final_man = shifted_man_temp[22:0];
                end
                end
                // Check for Exponent Overflow (becomes Infinity)
        if (final_exp == 8'hFF) begin
            overflow_w = 1'b1;
            final_exp  = 8'hFF;
            final_man  = 23'd0;
        end
        
        // Handle True Zero Result
        if (is_zero_result) begin
            final_exp  = 8'd0;
            final_man  = 23'd0;
            final_sign = 1'b0; // Zero is positive
        end
end
always @(posedge clk) begin
        if (rst) begin
            result    <= 32'd0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end
        else begin
            // Register all outputs
            result    <= {final_sign, final_exp, final_man};
            overflow  <= overflow_w;
            underflow <= underflow_w;
        end
    end
endmodule
module fp_mult (
    input wire clk,
    input wire rst,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    output reg [31:0] result,
    output reg overflow,
    output reg underflow
);
    // Deconstruct operands
    wire sign_a = operand_a[31];
    wire [7:0] exp_a = operand_a[30:23];
    wire [22:0] man_a = operand_a[22:0];

    wire sign_b = operand_b[31];
    wire [7:0] exp_b = operand_b[30:23];
    wire [22:0] man_b = operand_b[22:0];
      
    reg res_sign;
    reg [8:0] res_exp;
    reg [23:0] full_man_a;
    reg [23:0] full_man_b;
    reg [47:0] man_product;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 32'b0;
            overflow <= 1'b0;
            underflow <= 1'b0;
        end else begin
            // Step 1: Calculate result sign
             res_sign = sign_a ^ sign_b;

            // Step 2: Calculate result exponent
            res_exp = exp_a + exp_b - 127;

            // Step 3: Multiply mantissas (with implicit '1')
            full_man_a = {1'b1, man_a};
            full_man_b = {1'b1, man_b};
            man_product = full_man_a * full_man_b;

            // Step 4: Normalize
            if (man_product[47]) begin
                man_product = man_product >> 1;
                res_exp = res_exp + 1;
            end

            // Check for overflow/underflow
            overflow <= (res_exp > 254);
            underflow <= (res_exp < 1);

            // Pack the result
            result <= {res_sign, res_exp[7:0], man_product[45:23]};
        end
    end
endmodule
module fp_div (
    input wire clk,
    input wire rst,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    output reg [31:0] result,
    output reg overflow,
    output reg underflow,
    output reg zero_divide
);

    // Deconstruct operands
    wire sign_a = operand_a[31];
    wire [7:0] exp_a = operand_a[30:23];
    wire [22:0] man_a = operand_a[22:0];

    wire sign_b = operand_b[31];
    wire [7:0] exp_b = operand_b[30:23];
    wire [22:0] man_b = operand_b[22:0];

    // --- Combinational Logic for Calculations ---
    
    // Internal wires for the next values to be registered
    wire is_zero_divide_next;
    wire res_sign_next;
    wire [8:0] res_exp_unnormalized;
    wire [47:0] full_man_a_dividend;
    wire [23:0] full_man_b_divisor;
    wire [23:0] man_quotient_unnormalized;
    wire [23:0] man_quotient_next;
    wire [8:0] res_exp_next;
    wire overflow_next;
    wire underflow_next;
    wire [31:0] result_next;
    wire needs_normalization;

    // Check for division by zero
    assign is_zero_divide_next = (operand_b[30:0] == 31'b0);

    // Step 1: Sign calculation
    assign res_sign_next = sign_a ^ sign_b;

    // Step 2: Exponent calculation (initial)
    // Use 9 bits to avoid overflow during subtraction
    assign res_exp_unnormalized = {1'b0, exp_a} - {1'b0, exp_b} + 9'd127;

    // Step 3: Divide mantissas (with implicit '1')
    // full_man_a is 1.M_a scaled by 2^23
    assign full_man_a_dividend = {{1'b1, man_a}, 23'b0};
    assign full_man_b_divisor = {1'b1, man_b};
    
    // WARNING: This line synthesizes to a 48-bit / 24-bit divider.
    // This will be extremely large and slow. For a real chip,
    // this would be a multi-cycle state machine.
    assign man_quotient_unnormalized = full_man_a_dividend / full_man_b_divisor;

    // Step 4: Normalization (Replaced 'while' loop)
    // Check if the result was 0.1xxxxx... (i.e., MSB is 0)
    assign needs_normalization = (man_quotient_unnormalized[23] == 0 && man_quotient_unnormalized != 0);

    // If it needs normalization, shift left once
    assign man_quotient_next = needs_normalization 
                             ? (man_quotient_unnormalized << 1) 
                             : man_quotient_unnormalized;
    
    // If we shifted, we must decrement the exponent
    assign res_exp_next = needs_normalization 
                        ? (res_exp_unnormalized - 1) 
                        : res_exp_unnormalized;

    // Step 5: Check for overflow/underflow
    assign overflow_next = (res_exp_next > 254);
    assign underflow_next = (res_exp_next < 1);

    // Step 6: Pack the final result
    assign result_next = {res_sign_next, res_exp_next[7:0], man_quotient_next[22:0]};


    // --- Sequential Logic (Registers) ---
    // This block only assigns values to registers at the clock edge.
    // All calculations happen in the combinational logic above.
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 32'b0;
            overflow <= 1'b0;
            underflow <= 1'b0;
            zero_divide <= 1'b0;
        end else begin
            // Register all outputs based on the combinational logic
            zero_divide <= is_zero_divide_next;
            
            if (is_zero_divide_next) begin
                // On divide by zero, output should be Infinity
                result <= {res_sign_next, 8'hFF, 23'b0};
                overflow <= 1'b1; // Division by zero is often flagged as overflow
                underflow <= 1'b0;
            end else begin
                // Handle special cases for overflow/underflow results
                if (overflow_next) begin
                    result <= {res_sign_next, 8'hFF, 23'b0}; // Infinity
                end else if (underflow_next) begin
                    result <= 32'b0; // Denormal or zero
                end else begin
                    result <= result_next;
                end
                
                overflow <= overflow_next;
                underflow <= underflow_next;
            end
        end
    end

endmodule