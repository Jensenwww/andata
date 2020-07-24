/////////////////////////////////////////////////////////////////
//                                                             //
//    ██████╗  ██████╗  █████╗                                 //
//    ██╔══██╗██╔═══██╗██╔══██╗                                //
//    ██████╔╝██║   ██║███████║                                //
//    ██╔══██╗██║   ██║██╔══██║                                //
//    ██║  ██║╚██████╔╝██║  ██║                                //
//    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝                                //
//          ██╗      ██████╗  ██████╗ ██╗ ██████╗              //
//          ██║     ██╔═══██╗██╔════╝ ██║██╔════╝              //
//          ██║     ██║   ██║██║  ███╗██║██║                   //
//          ██║     ██║   ██║██║   ██║██║██║                   //
//          ███████╗╚██████╔╝╚██████╔╝██║╚██████╗              //
//          ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝              //
//                                                             //
//    APB Mux - Allows multiple slaves on one APB bus          //
//      Generates slave PSELs                                  //
//      Decodes PREADY, PSLVERR, PRDATA                        //
//                                                             //
/////////////////////////////////////////////////////////////////
//                                                             //
//             Copyright (C) 2016-2017 ROA Logic BV            //
//             www.roalogic.com                                //
//                                                             //
//    Unless specifically agreed in writing, this software is  //
//  licensed under the RoaLogic Non-Commercial License         //
//  version-1.0 (the "License"), a copy of which is included   //
//  with this file or may be found on the RoaLogic website     //
//  http://www.roalogic.com. You may not use the file except   //
//  in compliance with the License.                            //
//                                                             //
//    THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY        //
//  EXPRESS OF IMPLIED WARRANTIES OF ANY KIND.                 //
//  See the License for permissions and limitations under the  //
//  License.                                                   //
//                                                             //
/////////////////////////////////////////////////////////////////

 
module apb_mux #(
  parameter  PADDR_SIZE = 12,
             PDATA_SIZE = 32,
             SLAVES     = 2
)
(
  //Common signals
  input                   PRESETn,
                          PCLK,

  //To/From APB master
  input                   MST_PSEL,
  input  [PADDR_SIZE-1:0] MST_PADDR, //MSBs of address bus
  input  [PDATA_SIZE-1:0] MST_PWDATA,
  input                   MST_PWRITE,
  input                   MST_PENABLE,
  output [PDATA_SIZE-1:0] MST_PRDATA,
  output                  MST_PREADY,
  output                  MST_PSLVERR,
  
  input                   mst_rx_i,
  output                  mst_tx_o,
  output                  mst_event_o
  

  //To/from APB slaves
  input  [PADDR_SIZE-1:0] slv_addr   [SLAVES], //address compare for each slave
  input  [PADDR_SIZE-1:0] slv_mask   [SLAVES],
  output                  SLV_PSEL   [SLAVES],
  input  [PDATA_SIZE-1:0] SLV_PRDATA [SLAVES],
  input                   SLV_PREADY [SLAVES],
  input                   SLV_PSLVERR[SLAVES],
  input  [PDATA_SIZE-1:0] SLV_PWDATA [SLAVES],
  input                   SLV_PWRITE [SLAVES],
  input                   SLV_PENABLE[SLAVES]，
 
  input                   slv_rx_i   [SLAVES],
  output                  slv_tx_o   [SLAVES],
  output                  slv_event_o[SLAVES]
);
 
 //uart slaves
  apb_uart_sv apb_uart_sv_0
 (
  .CLK        ( PCLK                            )
  .RSTN       ( PRESETn                         )
  .PADDR      ( [PADDR_SIZE-1:0] slv_addr   [0] )
  .PWDATA     ( SLV_PWDATA                  [0] )
  .PWRITE     ( SLV_PWRITE                  [0] )
  .PSEL       ( SLV_PSEL                    [0] )
  .PENABLE    ( SLV_PENABLE                 [0] )
  .PRDATA     ( [PDATA_SIZE-1:0] SLV_PRDATA [0] )
  .PREADY     ( SLV_PREADY                  [0] )
  .PSLVERR    ( SLV_PSLVERR                 [0] )

  .rx_i       ( rx_i                        [0] )
  .tx_o       ( tx_o                        [0] )
  .event_o    ( event_o                     [0] )
);
 
   apb_uart_sv apb_uart_sv_1
 (
  .CLK        ( PCLK                            )
  .RSTN       ( PRESETn                         )
  .PADDR      ( [PADDR_SIZE-1:0] slv_addr   [1] )
  .PWDATA     ( SLV_PWDATA                  [1] )
  .PWRITE     ( SLV_PWRITE                  [1] )
  .PSEL       ( SLV_PSEL                    [1] )
  .PENABLE    ( SLV_PENABLE                 [1] )
  .PRDATA     ( [PDATA_SIZE-1:0] SLV_PRDATA [1] )
  .PREADY     ( SLV_PREADY                  [1] )
  .PSLVERR    ( SLV_PSLVERR                 [1] )

  .rx_i       ( slv_rx_i                    [1] )
  .tx_o       ( slv_tx_o                    [1] )
  .event_o    ( slv_event_o                 [1] )
);
  
  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  import ahb3lite_pkg::*;


  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [SLAVES-1:0][PDATA_SIZE-1:0] prdata;
  logic [SLAVES-1:0][PDATA_SIZE-1:0] pwdata;
  logic [SLAVES-1:0]                 pready;
  logic [SLAVES-1:0]                 pslverr;
  logic [SLAVES-1:0]                 penable;
  logic [SLAVES-1:0]                 pwrite;
  
  logic [SLAVES-1:0]                 RX_I;
  logic [SLAVES-1:0]                 TX_O;
  logic [SLAVES-1:0]                 EVENT_O;

  logic [PDATA_SIZE-1:0][SLAVES-1:0] prdata_switched;
  logic [PDATA_SIZE-1:0][SLAVES-1:0] pwdata_switched;


  genvar s,b;


  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
generate
    for (s=0;s<SLAVES;s++)
    begin: aa
        /*
         * Decode addresses
         */
        assign SLV_PSEL[s] = MST_PSEL & ( (MST_PADDR & slv_mask[s]) == (slv_addr[s] & slv_mask[s]) );


        /*
         * Mux slave responses
         */
        assign prdata [s] = SLV_PRDATA [s] & {PDATA_SIZE{SLV_PSEL[s]}};
        assign pwdata [s] = SLV_PWDATA [s] & {PWATA_SIZE{SLV_PSEL[s]}};
       
        assign pready [s] = SLV_PREADY [s] & SLV_PSEL[s];
        assign pslverr[s] = SLV_PSLVERR[s] & SLV_PSEL[s];
        assign penable[s] = SLV_PENABLE[s] & SLV_PSEL[s];
        assign pwrite [s] = SLV_PWRITE [s] & SLV_PSEL[s];
        assign pwrite [s] = SLV_PWRITE [s] & SLV_PSEL[s];
     
        assign RX_I   [s] = slc_rx_i   [s] & SLV_PSEL[s];
        assign TX_O   [s] = slc_tx_o   [s] & SLV_PSEL[s];
        assign EVENT_O[s] = slc_event_o[s] & SLV_PSEL[s];
    end
endgenerate


generate
  for (s=0;s<SLAVES;     s++)
  begin: bb
      for (b=0;b<PDATA_SIZE;b++)
      begin: cc
          assign prdata_switched[b][s] = prdata[s][b];
          assign pwdata_switched[b][s] = pwdata[s][b];
      end
  end

  for (b=0;b<PDATA_SIZE;b++)
  begin: dd
      assign MST_PRDATA[b] = |prdata_switched[b];
      assign MST_PWDATA[b] = |pwdata_switched[b];
  end
endgenerate


  assign MST_PREADY  = |pready;
  assign MST_PSLVERR = |pslverr;
  assign MST_PENABLE = |penable;
  assign MST_PWRITE  = |pwrite;

  assign mst_rx_i    = |RX_I;
  assign mst_tx_o    = |TX_O;
  assign mst_event_o = |EVENT_O;
 
endmodule
