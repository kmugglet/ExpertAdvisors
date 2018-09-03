//+------------------------------------------------------------------+
//|                                          elphebaSplunkOrders.mq4 |
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

double   LotPrice=1; // baby steps
int   version=20180401;

//--- input parameters
extern double    tp = 230;
extern double    dp = 30;
extern double    sl = 7500;
extern int       max_trades=8; // max trades per symbol pair
extern double    bufferEquity=0; // use this to emulate transfers between accounts. Start with 200, add 10,000. Only 200 will be seen by EA
extern bool      instant_close=true;
extern bool      openTrades=true;
extern bool      closeTrades=true;

int      tkt,lowest_ticket,highest_ticket;

double   take,stop;
double   CloseOutPrice,EquityCheck,order_points;
int      RSIperiod=14;
int      AppliedPrice=4;
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
bool     rsi_swap=true;
bool     close_up=false,pause=false;
bool     this_rsi,last_rsi,stoch_buy,stoch_sell,close_email=false,bNB,bM1,bW1;
bool     ma_close,profit_close[999],trigger_reached[999],order_exists[999],res;
double   current_profit[999],tkt_open[999],tkt_high[999],tkt_low[999],tkt_close[999];
int      hedge_tkt[999],h_tkt;
double   symbol_profit;
double   f_profit[999];
double   RSIprev;
int      open_trades[1000],open_tickets;
double   iStochvalue=0;
double   RSInow,RSIlast;

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
//| initialise functions                                             |
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
//|                                                                  |
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
//|                                                                  |
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
//|                                                                  |
//+------------------------------------------------------------------+

int CheckForOpen()
  {
   string acctUrl="http://kmug.ddns.net/elpheba/"+DoubleToStr(AccountNumber(),0)+"/";
   string checkForUpdate=GrabWeb(acctUrl,simEquity());
   string sep=",";                // A separator as a character
   ushort u_sep;                  // The code of the separator character
   string result[];               // An array to get strings
//--- Get the separator code
   u_sep=StringGetCharacter(sep,0);
//--- Split the string to substrings
   int k=StringSplit(checkForUpdate,u_sep,result);
   if(k==2)
     {
      Withdrawls=(double) result[0];
      Deposits=(double) result[1];
     }

   return(0);
  }
//+------------------------------------------------------------------+
//| expert initialization function                                 |
//+------------------------------------------------------------------+


void OnInit()
  {

   Print("Re-init");

   open_tickets=0;

   for(int f=0;f<=97;f++)
     {
      profit_close[f]=false;
      trigger_reached[f]=false;
      order_exists[f]=false;
      open_trades[f]=-1;
      current_profit[f]=0.0;
      tkt_open[f]=0.0;
      tkt_close[f]= 0.0;
      tkt_high[f] = 0.0;
      tkt_low[f]=100000.0;
      hedge_tkt[f]= 0;
      f_profit[f] = -9999.0;
     }

   return;
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
  {
   FileFlush(handle);
   FileClose(handle);
   Print("Final simEquity : ",simEquity(),", simBalance : ",simBalance(),", Withdrawls : ",Withdrawls);
   EventKillTimer();

   return;
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

   updateEquity=0;

   if(bNB && !close_up && !pause && openTrades && OrdersTotal()<max_trades && simMargin()>EquityCheck) CheckForOpen(); // This is more conservative as it takes into account moneys used in the trade itself.

   if(!IsTesting()) FileFlush(handle);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

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
string GrabWeb(string strUrl,double currentEquity)
  {
   string headers,response;
   char post[],result[];
   int httpRes,timeout=5000;
   char data[];
   string login=DoubleToStr(AccountNumber(),0);
   string password="pass";
   string str="Acct="+login+"&Password="+password+"&Equity="+DoubleToStr(currentEquity,2);

   ArrayResize(data,StringToCharArray(str,data,0,WHOLE_ARRAY,CP_UTF8)-1);

   ResetLastError();
   httpRes=WebRequest("GET",strUrl,"",NULL,1000,data,ArraySize(data),result,headers);

//Print("Status code: ",httpRes,", error: ",GetLastError());
   response=CharArrayToString(result);
   Print("Server response: ",response);
   return(response);
  }
//+--------------------------------------------------------------+
void mySleep(int seconds)
  {
   for(int tick=0;tick<=seconds;tick++)
     {
      Sleep(1000);
     }

  }
//+------------------------------------------------------------------+
