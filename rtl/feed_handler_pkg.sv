package feed_handler_pkg;

    localparam logic [15:0] ETHERTYPE_IPV4 = 16'h0800;
    localparam logic [7:0]  IPV4_VERSION_IHL = 8'h45;
    localparam logic [7:0]  IPV4_PROTOCOL_UDP = 8'h11;

    localparam logic [7:0] MARKET_PROTOCOL_VERSION = 8'h01;
    localparam logic [7:0] MESSAGE_ADD_ORDER = 8'h01;
    localparam logic [7:0] MESSAGE_CANCEL_ORDER = 8'h02;
    localparam logic [7:0] MESSAGE_TRADE = 8'h03;
    localparam logic [7:0] MESSAGE_SYSTEM_EVENT = 8'h04;

    localparam int unsigned ETHERNET_HEADER_BYTES = 14;
    localparam int unsigned IPV4_HEADER_BYTES = 20;
    localparam int unsigned UDP_HEADER_BYTES = 8;
    localparam int unsigned MARKET_MESSAGE_BYTES = 16;

    typedef enum logic [3:0] {
        REJECT_NONE,
        REJECT_SHORT_ETHERNET,
        REJECT_ETHERTYPE,
        REJECT_SHORT_IPV4,
        REJECT_IPV4_VERSION,
        REJECT_IPV4_HEADER_LENGTH,
        REJECT_FRAGMENTED,
        REJECT_NON_UDP,
        REJECT_DESTINATION_MAC,
        REJECT_DESTINATION_IP,
        REJECT_SHORT_UDP,
        REJECT_DESTINATION_PORT,
        REJECT_SHORT_PAYLOAD,
        REJECT_PROTOCOL_VERSION,
        REJECT_MESSAGE_TYPE
    } reject_reason_t;

endpackage
