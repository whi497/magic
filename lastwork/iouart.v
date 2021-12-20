`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/03/24 10:33:43
// Design Name: 
// Module Name: top
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

module iouart(
input               clk,rst,
input               rx,
output              tx,
input               er,        
output              is_rst_cmd,
output              is_start_cmd,
output              is_reset_cmd,
output              is_check_cmd,
output              is_setcl_cmd,
output              is_exit_cmd,
output              is_shutdown_cmd,
output  reg               wr_ry,
output  reg[3:0]          clock1,
output  reg[3:0]          clock2,
output  reg[3:0]          clock3,
output  reg[3:0]          clock4,
output  reg[3:0]          clock5,
output  reg[3:0]          clock6  
);

parameter   C_IDLE          = 4'b0000;//空闲状态，接收到串口数据后跳转到下一状态C_CMD_DC
parameter   C_CMD_DC        = 4'b0010;//解码命令状态，解析缓冲区中的命令类型，如写字节、读字节等
parameter   C_CMD_WB        = 4'b0011;//写数据阶段，根据命令内容，将数据写入对应地址，如:wb 01 f0,则向01号地址写入数据f0 
parameter   C_CMD_RB        = 4'b0100;//读数据阶段，根据命令内容，读取对应地址的数据，如:rb a1,则从a1地址读取数据  
parameter   C_CMD_ERR       = 4'b0111;//错误状态，上位机发送的命令格式有误时进入此状态，向上位机发送“ERROR！”字样 
parameter   C_TXFIFO_WR     = 4'b0101;//等待阶段，将数据或返回信息以ASCII码格式存入发送缓冲区
parameter   C_TXFIFO_WAIT   = 4'b0110;//发送等待阶段，将发送缓冲区中的数据依次以ASCII码格式从串口发出
wire                tx_ready;
wire        [7:0]   tx_data;
wire        [7:0]   rx_data;

reg         [3:0]   curr_state;
reg         [3:0]   next_state;

wire                is_s_cmd;
wire                is_rb_cmd;

reg         [3:0]   tx_byte_cnt;

reg         [3:0]   rx_byte_cnt;
reg         [7:0]   rx_byte_buff_0;
reg         [7:0]   rx_byte_buff_1;
reg         [7:0]   rx_byte_buff_2;
reg         [7:0]   rx_byte_buff_3;
reg         [7:0]   rx_byte_buff_4;
reg         [7:0]   rx_byte_buff_5;
reg         [7:0]   rx_byte_buff_6;
reg         [7:0]   rx_byte_buff_7;

reg         [7:0]   tx_byte_buff_0;
reg         [7:0]   tx_byte_buff_1;
reg         [7:0]   tx_byte_buff_2;
reg         [7:0]   tx_byte_buff_3;
reg         [7:0]   tx_byte_buff_4;
reg         [7:0]   tx_byte_buff_5;
reg         [7:0]   tx_byte_buff_6;
reg         [7:0]   tx_byte_buff_7;

reg                 rx_fifo_en;
wire     [7:0]      rx_fifo_data;
wire                rx_fifo_empty;

// reg      [7:0]      wr_addr;
// reg      [7:0]      wr_data;

reg                 rd_en;
reg      [7:0]      rd_addr;
reg      [7:0]      rd_data;

reg      [7:0]      tx_fifo_din;
reg                 tx_fifo_wr_en;
wire                tx_fifo_full;
wire                tx_fifo_empty;


always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        tx_fifo_wr_en   <= 1'b0;
        tx_fifo_din     <= 8'h0;
    end
    else if(curr_state==C_TXFIFO_WR)
    begin
        tx_fifo_wr_en   <= 1'b1;
        case(tx_byte_cnt)
            4'h6:   tx_fifo_din <= tx_byte_buff_6;
            4'h5:   tx_fifo_din <= tx_byte_buff_5;
            4'h4:   tx_fifo_din <= tx_byte_buff_4;
            4'h3:   tx_fifo_din <= tx_byte_buff_3;
            4'h2:   tx_fifo_din <= tx_byte_buff_2;
            4'h1:   tx_fifo_din <= tx_byte_buff_1;
            4'h0:   tx_fifo_din <= tx_byte_buff_0;
            default:tx_fifo_din <= 8'h0;
        endcase
    end
    else
    begin
        tx_fifo_wr_en   <= 1'b0;
        tx_fifo_din     <= 8'h0;
    end
end

always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        rd_en        <= 1'b0;
        rd_addr[7:4] <= 4'h0; 
        rd_addr[3:0] <= 4'h0; 
    end    
    else if(curr_state==C_CMD_RB)
    begin
        rd_en   <= 1'b1;
        if((rx_byte_buff_3>="0")&&(rx_byte_buff_3<="9"))
            rd_addr[7:4] <= rx_byte_buff_3[3:0];
        else
            rd_addr[7:4] <= rx_byte_buff_3[2:0] + 4'h9;
        if((rx_byte_buff_4>="0")&&(rx_byte_buff_4<="9"))
            rd_addr[3:0] <= rx_byte_buff_4[3:0];
        else
            rd_addr[3:0] <= rx_byte_buff_4[2:0] + 4'h9;
    end    
    else
    begin
        rd_en   <= 1'b0;
        rd_addr[7:4] <= 4'h0; 
        rd_addr[3:0] <= 4'h0; 
    end    
end   
always@(posedge clk or posedge rst)
begin
    if(rst)
        tx_byte_cnt <= 4'h0;
    else if(curr_state==C_IDLE)
        tx_byte_cnt <= 4'h0;
    else if(curr_state==C_CMD_RB)//读字节，发送字节数据的ASCII码及换行符，如“0f\n”
        tx_byte_cnt <= 4'h2;
    else if(curr_state==C_CMD_ERR)//错误状态，发送字符串“ERROR！\n”
        tx_byte_cnt <= 4'h6;
    else if(curr_state==C_TXFIFO_WR)
    begin
        if(tx_byte_cnt!=4'h0)
            tx_byte_cnt <= tx_byte_cnt - 4'h1;
    end
end

always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        tx_byte_buff_0  <= 8'h0;
        tx_byte_buff_1  <= 8'h0;
        tx_byte_buff_2  <= 8'h0;
        tx_byte_buff_3  <= 8'h0;
        tx_byte_buff_4  <= 8'h0;
        tx_byte_buff_5  <= 8'h0;
        tx_byte_buff_6  <= 8'h0;
        tx_byte_buff_7  <= 8'h0;
    end
    else if(curr_state==C_IDLE)
    begin
        tx_byte_buff_0  <= 8'h0;
        tx_byte_buff_1  <= 8'h0;
        tx_byte_buff_2  <= 8'h0;
        tx_byte_buff_3  <= 8'h0;
        tx_byte_buff_4  <= 8'h0;
        tx_byte_buff_5  <= 8'h0;
        tx_byte_buff_6  <= 8'h0;
        tx_byte_buff_7  <= 8'h0;
    end
    else if(curr_state==C_CMD_RB)
    begin
        tx_byte_buff_0  <= "\n";
        if(rd_data[7:4]<=4'h9)
            tx_byte_buff_2  <= {4'h3,rd_data[7:4]};
        else
            tx_byte_buff_2  <= rd_data[7:4] - 4'ha + "a";
        if(rd_data[3:0]<=4'h9)
            tx_byte_buff_1  <= {4'h3,rd_data[3:0]};
        else
            tx_byte_buff_1  <= rd_data[3:0] - 4'ha + "a";
    end
    else if(curr_state==C_CMD_ERR)
    begin
        tx_byte_buff_6  <= "E";
        tx_byte_buff_5  <= "R";
        tx_byte_buff_4  <= "R";
        tx_byte_buff_3  <= "O";
        tx_byte_buff_2  <= "R";
        tx_byte_buff_1  <= "!";
        tx_byte_buff_0  <= "\n";
    end
end


always@(posedge clk or posedge rst)
begin
    if(rst)
        curr_state  <= C_IDLE;
    else
        curr_state  <= next_state;
end
always@(*)
begin
    case(curr_state)
        C_IDLE:
            if((rx_vld==1'b1)&&(rx_data==8'h0a)) //检测到换行符，表示命令已经全部缓冲到FIFO内
                next_state  = C_CMD_DC;
            else if(er)
                next_state <= C_CMD_ERR;
            else
                next_state  = C_IDLE;
        C_CMD_DC:
            if(rx_fifo_empty)
            begin
                if(is_s_cmd)
                    next_state  = C_CMD_WB;
                else if(is_rb_cmd)
                    next_state  = C_CMD_RB;
                else if(is_check_cmd)
                    next_state = C_IDLE;
                else
                    next_state  = C_CMD_ERR;
            end
            else
                next_state  = C_CMD_DC;
        C_CMD_WB:
            next_state  = C_IDLE;
        C_CMD_RB:
            if(rd_en==1'b1)
                next_state  = C_TXFIFO_WR;
            else
                next_state  = C_CMD_RB;
        C_CMD_ERR:
            next_state  = C_TXFIFO_WR;
        C_TXFIFO_WR:
            if(tx_byte_cnt==4'h0)
                next_state = C_TXFIFO_WAIT;
            else
                next_state = C_TXFIFO_WR;
        C_TXFIFO_WAIT:
            if(tx_fifo_empty)
                next_state = C_IDLE;
            else
                next_state = C_TXFIFO_WAIT;
        default:
            next_state      = C_IDLE;
    endcase
end

always@(posedge clk or posedge rst)
begin
    if(rst)
        rx_fifo_en  <= 1'b0;
    else if(curr_state==C_CMD_DC)
        rx_fifo_en  <= 1'b1;
    else
        rx_fifo_en  <= 1'b0;
end
always@(posedge clk or posedge rst)//接收计数，并用于对命令中的各字节编号
begin
    if(rst)
        rx_byte_cnt <= 4'h0;
    else if(curr_state==C_CMD_DC)
    begin
        if((rx_fifo_en)&&(rx_fifo_empty==1'b0)&&(rx_byte_cnt<4'hf))
            rx_byte_cnt <= rx_byte_cnt + 4'b1;
    end
    else
        rx_byte_cnt <= 4'h0;
end
always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        rx_byte_buff_0  <= 8'h0;
        rx_byte_buff_1  <= 8'h0;
        rx_byte_buff_2  <= 8'h0;
        rx_byte_buff_3  <= 8'h0;
        rx_byte_buff_4  <= 8'h0;
        rx_byte_buff_5  <= 8'h0;
        rx_byte_buff_6  <= 8'h0;
        rx_byte_buff_7  <= 8'h0;
    end
    else if(curr_state==C_IDLE)
    begin
        rx_byte_buff_0  <= 8'h0;
        rx_byte_buff_1  <= 8'h0;
        rx_byte_buff_2  <= 8'h0;
        rx_byte_buff_3  <= 8'h0;
        rx_byte_buff_4  <= 8'h0;
        rx_byte_buff_5  <= 8'h0;
        rx_byte_buff_6  <= 8'h0;
        rx_byte_buff_7  <= 8'h0;
    end
    else if(curr_state==C_CMD_DC)
    begin
        case(rx_byte_cnt)
            4'h0:   rx_byte_buff_0 <= rx_fifo_data;
            4'h1:   rx_byte_buff_1 <= rx_fifo_data;
            4'h2:   rx_byte_buff_2 <= rx_fifo_data;
            4'h3:   rx_byte_buff_3 <= rx_fifo_data;
            4'h4:   rx_byte_buff_4 <= rx_fifo_data;
            4'h5:   rx_byte_buff_5 <= rx_fifo_data;
            4'h6:   rx_byte_buff_6 <= rx_fifo_data;
            4'h7:   rx_byte_buff_7 <= rx_fifo_data;
        endcase
    end
end 
assign  is_s_cmd     = (curr_state==C_CMD_DC&&(rx_byte_buff_0=="s")&&(rx_byte_buff_1==" ")
                    &&(rx_byte_buff_2>="0")&&(rx_byte_buff_2<="2")&&(rx_byte_buff_3>="0")&&
                    (rx_byte_buff_3=="9"))&&(rx_byte_buff_4>="0")&&(rx_byte_buff_4<="6")&&
                    (rx_byte_buff_5>="0")&&(rx_byte_buff_5<="9")&&(rx_byte_buff_6>="0")&&
                    (rx_byte_buff_6<="6")&&(rx_byte_buff_7>="0")&&(rx_byte_buff_7<="9");
assign  is_check_cmd = (curr_state==C_CMD_DC)&&(rx_byte_buff_0=="c")&&(rx_byte_buff_1=="h")
                    &&(rx_byte_buff_2=="e")&&(rx_byte_buff_3=="c")&&(rx_byte_buff_4=="k");
assign  is_start_cmd = (curr_state==C_CMD_DC)&&(rx_byte_buff_0=="s")&&(rx_byte_buff_1=="t")
                    &&(rx_byte_buff_2=="a")&&(rx_byte_buff_3=="r")&&(rx_byte_buff_4=="t");
assign  is_reset_cmd = (curr_state==C_CMD_DC)&&(rx_byte_buff_0=="r")&&(rx_byte_buff_1=="e")
                    &&(rx_byte_buff_2=="s")&&(rx_byte_buff_3=="e")&&(rx_byte_buff_4=="t");
assign  is_setcl_cmd = (curr_state==C_CMD_DC)&&(rx_byte_buff_0=="s")&&(rx_byte_buff_1=="e")
                    &&(rx_byte_buff_2=="t")&&(rx_byte_buff_3=="c")&&(rx_byte_buff_4=="l");                 
assign  is_exit_cmd = (curr_state==C_CMD_DC)&&(rx_byte_buff_0=="e")&&(rx_byte_buff_1=="x")
                    &&(rx_byte_buff_2=="i")&&(rx_byte_buff_3=="t");
assign  is_shutdown_cmd = (curr_state==C_CMD_DC)&&(rx_byte_buff_0=="s")&&(rx_byte_buff_1=="h")
                    &&(rx_byte_buff_2=="u")&&(rx_byte_buff_3=="t")&&(rx_byte_buff_4=="d")
                    &&(rx_byte_buff_5=="o")&&(rx_byte_buff_6=="w")&&(rx_byte_buff_7=="n");

always@(posedge clk or posedge rst)
begin
    if(rst)
    begin
        wr_ry   <= 1'b0;
        clock1 <=0;clock2<=0;clock3<=0;
        clock4 <=0;clock5<=0;clock6<=0;
        // wr_addr[7:4] <= 4'h0;
        // wr_addr[3:0] <= 4'h0;
        // wr_data[7:4] <= 4'h0;
        // wr_data[3:0] <= 4'h0;
    end
    else if(curr_state == C_CMD_WB)
    begin
        wr_ry   <= 1'b1;
        clock1 <= rx_byte_buff_2-8'd48;
        clock2 <= rx_byte_buff_3-8'd48;
        clock3 <= rx_byte_buff_4-8'd48;
        clock4 <= rx_byte_buff_5-8'd48;
        clock5 <= rx_byte_buff_6-8'd48;
        clock6 <= rx_byte_buff_7-8'd48;
    end
    else
    begin
        wr_ry   <= 1'b0;
        // wr_addr[7:4] <= 4'h0;
        // wr_addr[3:0] <= 4'h0;
        // wr_data[7:4] <= 4'h0;
        // wr_data[3:0] <= 4'h0;
    end
end    


rx                  rx_inst(
.clk                (clk),
.rst                (rst),
.rx                 (rx),
.rx_vld             (rx_vld),
.rx_data            (rx_data)
);                     
tx                  tx_inst(
.clk                (clk),
.rst                (rst),
.tx                 (tx ),
.tx_ready           (~tx_fifo_empty),
.tx_rd              (tx_rd),
.tx_data            (tx_data)
);

fifo_32x8bit_0      rx_fifo( //用于缓存串口发来的命令
.clk                (clk), 
.rst                (rst), 
.din                (rx_data), 
.wr_en              (rx_vld), 
.rd_en              (rx_fifo_en), 
.dout               (rx_fifo_data), 
.full               (), 
.empty              (rx_fifo_empty)
);

fifo_32x8bit_0      tx_fifo( //用于缓存将要通过串口发送出去的内容
.clk                (clk), 
.rst                (rst), 
.din                (tx_fifo_din), 
.wr_en              (tx_fifo_wr_en), 
.rd_en              (tx_rd), 
.dout               (tx_data), 
.full               (tx_fifo_full), 
.empty              (tx_fifo_empty)
);

endmodule
