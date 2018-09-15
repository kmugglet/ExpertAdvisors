//+------------------------------------------------------------------+
//|                                                 elphebaHedge.mq4 |
//|                                      Copyright 2018,Codatrek.com |
//|                                         https://www.codatrek.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018,Codatrek.com"
#property link      "https://www.codatrek.com"
#property strict
/*  "HIGH RISK WARNING: Foreign exchange trading carries a high level of risk that may not be suitable for all investors.
   Leverage creates additional risk and loss exposure.
   Before you decide to trade foreign exchange, carefully consider your investment objectives, experience level, and risk tolerance.
   You could lose some or all of your initial investment; do not invest money that you cannot afford to lose.
   Educate yourself on the risks associated with foreign exchange trading, and seek advice from an independent financial or tax advisor if you have any questions.
   Any data and information is provided 'as is' solely for informational purposes, and is not intended for trading purposes or advice."
*/

double   LotPrice=0.02; // baby steps
int   version=20180823;

//--- input parameters

extern double    tp = 10;
extern double    dp = 10;
extern double    sl = 7500;
extern double    bufferEquity=0; // use this to emulate transfers between accounts. Start with 200, add 10,000. Only 200 will be seen by EA
extern bool      instant_close=true;
extern bool      openTrades=true;
extern bool      closeTrades=true;

static bool first=true;
static int pre_OrdersTotal=0;
int _OrdersTotal=OrdersTotal();

int      tkt,lowest_ticket,highest_ticket;

double   take,stop;
double   CloseOutPrice,EquityCheck,order_points;
double   trigger_profit;
double   drop_profit;
double   stop_loss;
double   ask_price,bid_price,points,ask_p,bid_p,pts;
string   Check_Symbol,suffix="i";
int      SymbolOrders=0;
int      MAGICMA;
int      trades_won=0;
int      oldOrdersTotal=0,oldHistoryTotal=0,oldMaxTicket=0;

double   Lot,StartBalance,Withdrawls,WeeklyWithdrawl,Deposits,updateEquity,increaseTarget;
bool     openPair;
bool     close_up=false,pause=false;
bool     close_email=false,bNB,bM1,bW1;
bool     ma_close,profit_close[999],trigger_reached[999],order_exists[999],res;
double   current_profit[999],tkt_open[999],tkt_high[999],tkt_low[999],tkt_close[999];
int      hedge_tkt[999],h_tkt;
double   symbol_profit;
double   f_profit[999];
int      open_trades[1000],open_tickets;

string   filename;
int      handle,st;
string   order[]={"Buy","Sell"};
datetime LastTick[20]; // same number as symbol pairs or greater
datetime TimeNow;
bool     SymbolUsed[20]; // only open one trade under each currency
string   SymbolPairs[]=
  {
   "EURUSD","EURGBP","GBPUSD",
   "AUDUSD","EURJPY","AUDJPY",
   "EURAUD","USDCAD","USDJPY",
   "GBPCAD","AUDCAD","USDCHF",
   "GBPAUD"
  };
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
bool       bNewMin()
  {

   static datetime iTime_2=0;

   if(iTime_2<iTime(NULL,PERIOD_M1,0))
     { iTime_2=iTime(NULL,PERIOD_M1,0); return(TRUE); }
   else
     { return(FALSE); }
  }
//+------------------------------------------------------------------+
bool       bNewWeek()
  {

   static datetime iTime_1=0;

   if(iTime_1<iTime(NULL,PERIOD_W1,0))
     { iTime_1=iTime(NULL,PERIOD_W1,0); return(TRUE); }
   else
     { return(FALSE); }
  }
//+------------------------------------------------------------------+
bool       bNewBar()
  {

   static datetime iTime_0=0;

   if(iTime_0<iTime(NULL,NULL,0))
     { iTime_0=iTime(NULL,NULL,0); return(TRUE); }
   else
     { return(FALSE); }
  }
//+------------------------------------------------------------------+
void OpenNewHedgePair()
  {

   ask_price = MarketInfo(_Symbol,MODE_ASK);
   bid_price = MarketInfo(_Symbol,MODE_BID);

   points=MarketInfo(_Symbol,MODE_POINT);
   take = bid_price - ((tp + (2*dp))* points);
   stop = ask_price + (sl * points);
   res=OrderSend(_Symbol,OP_SELL,Lot,bid_price,3,NULL,take,NULL,MAGICMA,0,Red);
   take = ask_price + ((tp + (2*dp))* points);
   stop = bid_price - (sl * points);
   res=OrderSend(_Symbol,OP_BUY,Lot,ask_price,3,NULL,take,NULL,MAGICMA,0,Green);
   pre_OrdersTotal=OrdersTotal();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   Lot = GlobalVariableGet("globalLots");
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsTradeAllowed()==false) return;
   bNB = bNewBar();
   bM1 = bNewMin();
   bW1 = bNewWeek();

   if(GlobalVariableGet("globalCloseUp")>0)
     {
      close_up=true;
        } else {
      close_up=false;
     };

   updateEquity=0;

   if(first)
     {
      pre_OrdersTotal=_OrdersTotal;
      first=false;
      openPair=false;
     }

   _OrdersTotal=OrdersTotal();

// Compare the amount of positions on the previous tick to the current amount.
// If it has decreased then an order has closed so we should open a new pair.
   if(_OrdersTotal>=pre_OrdersTotal)
     {
      openPair=false;
      pre_OrdersTotal=_OrdersTotal;
     }
   if(_OrdersTotal<pre_OrdersTotal)
     {
      openPair=true;
     }
   if(_OrdersTotal<2)
     {
      openPair=true;
     }
   Lot = GlobalVariableGet("globalLots");
   if(bNB) Print("_OrdersTotal = ",_OrdersTotal,"  pre_OrdersTotal = ",pre_OrdersTotal,"  OrdersTotal() = ",OrdersTotal(),"  openPair = ",openPair);
   if(bNB && !close_up && !pause && openTrades && openPair && simMargin()>EquityCheck) OpenNewHedgePair(); // This is more conservative as it takes into account moneys used in the trade itself.;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double simEquity()
  {

   double Equity=AccountEquity()-Withdrawls+Deposits-bufferEquity;

   return Equity;
  }
//+------------------------------------------------------------------+
double simBalance()
  {

   double Balance=AccountBalance()-Withdrawls+Deposits-bufferEquity;

   return Balance;
  }
//+------------------------------------------------------------------+
double simMargin()
  {

   double Margin=AccountFreeMargin()-Withdrawls+Deposits-bufferEquity;

   return Margin;
  }
//+------------------------------------------------------------------+
