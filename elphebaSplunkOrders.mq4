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
int   version=20190114;

//--- input parameters
extern int      MAGICMA = 24771442;

int      tkt,lowest_ticket,highest_ticket;

double   take,stop;
double   CloseOutPrice,EquityCheck,order_points;
double   trigger_profit;
double   drop_profit;
double   stop_loss;
double   ask_price,bid_price,points,ask_p,bid_p,pts;
string   Check_Symbol,suffix="i";
int      SymbolOrders=0;

double   Lot,StartBalance,Withdrawls,WeeklyWithdrawl,Deposits,updateEquity,increaseTarget;
bool     close_up=false,pause=false;
bool     bNB,bM1,bW1;
bool     ma_close,profit_close[999],trigger_reached[999],order_exists[999],res;

int      open_trades[1000],open_tickets;

string   Order_Symbol,BuySell_Type,timeStamp;
double   Open_At,Stop_At,Take_At1,Take_At2,Order_Size;

int      Order_Type;
string   order[]={"Buy","Sell"};
datetime TimeNow;
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
   string acctUrl="http://kmug.ddns.net/elpheba/"+DoubleToStr(AccountNumber(),0)+"/newOrders";
   string checkForUpdate=GrabWeb(acctUrl,AccountEquity());
   string sep=",";                // A separator as a character
   ushort u_sep;                  // The code of the separator character
   string result[];               // An array to get strings
//--- Get the separator code
   u_sep=StringGetCharacter(sep,0);
//--- Split the string to substrings
   int k=StringSplit(checkForUpdate,u_sep,result);
   if(k==8)
     {
      timeStamp=(string) result[0];
      Order_Symbol=(string) result[1];
      BuySell_Type=(string) result[6];
      Open_At = (double) result[2];
      Stop_At = (double) result[3];
      Take_At1 = (double) result[4];
      Take_At2 = (double) result[5];
      Order_Size=(double) result[7];
      if(BuySell_Type=="Buy") Order_Type=OP_BUYLIMIT;
      if(BuySell_Type=="Sell") Order_Type=OP_SELLLIMIT;

      res=OrderSend(Order_Symbol,Order_Type,Order_Size,Open_At,3,Stop_At,Take_At1,NULL,MAGICMA,0,Red);
      res=OrderSend(Order_Symbol,Order_Type,Order_Size,Open_At,3,Stop_At,Take_At2,NULL,MAGICMA,0,Blue);
     }

   return(0);
  }
//+------------------------------------------------------------------+
//| expert initialization function                                 |
//+------------------------------------------------------------------+


void OnInit()
  {

   Lot=LotPrice;
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

   updateEquity=0;

   if(bNB && !close_up && !pause) CheckForOpen(); // This is more conservative as it takes into account moneys used in the trade itself.

  }
//+------------------------------------------------------------------+
//|                                                                  |
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
