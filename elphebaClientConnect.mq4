//+------------------------------------------------------------------+
//|                                         elphebaClientConnect.mq4 |
//|                                      Copyright 2017,Codatrek.com |
//|                                         https://www.codatrek.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017,Codatrek.com"
#property link      "https://www.codatrek.com"
#property strict
/*  "HIGH RISK WARNING: Foreign exchange trading carries a high level of risk that may not be suitable for all investors.
   Leverage creates additional risk and loss exposure.
   Before you decide to trade foreign exchange, carefully consider your investment objectives, experience level, and risk tolerance.
   You could lose some or all of your initial investment; do not invest money that you cannot afford to lose.
   Educate yourself on the risks associated with foreign exchange trading, and seek advice from an independent financial or tax advisor if you have any questions.
   Any data and information is provided 'as is' solely for informational purposes, and is not intended for trading purposes or advice."
*/

double    LotPrice=1; // baby steps
double version = 1.18;

//--- input parameters
extern double    BuyPoint=15;
extern double    SellPoint=85;
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
bool     this_rsi,last_rsi,stoch_buy,stoch_sell,close_up=false,close_email=false,bNB,bM1,bW1;
bool     ma_close,profit_close[99],trigger_reached[99],order_exists[99],res;
double   current_profit[99],tkt_open[99],tkt_high[99],tkt_low[99],tkt_close[99];
int      hedge_tkt[99],h_tkt;
double   symbol_profit;
double   f_profit[99];
double   RSIprev;
int      open_trades[100],open_tickets;
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
void CheckForOpen()
  {

   Print("Check for Openings");

   for(int a=0; a<ArraySize(SymbolPairs); a++)
     {
      Check_Symbol=SymbolPairs[a]+suffix;
      ask_price = MarketInfo(Check_Symbol,MODE_ASK);
      bid_price = MarketInfo(Check_Symbol,MODE_BID);
      points=MarketInfo(Check_Symbol,MODE_POINT);

      RSInow=iRSI(Check_Symbol,NULL,RSIperiod,AppliedPrice,0);
      RSIlast=iRSI(Check_Symbol,NULL,RSIperiod,AppliedPrice,1);

      iStochvalue=iStochastic(Check_Symbol,NULL,5,3,3,MODE_SMMA,1,MODE_MAIN,1);

      last_rsi = false;
      this_rsi = false;
      stoch_sell= false;
      stoch_buy = false;
      last_rsi = (RSIlast > 50);
      this_rsi = (RSInow > 50);
      rsi_swap=(last_rsi!=this_rsi);

      if(iStochvalue<BuyPoint)
        {
         stoch_buy=true;
        }
      if(iStochvalue>SellPoint)
        {
         stoch_sell=true;
        }
      Print(Check_Symbol," : Stoch - ",iStochvalue," - RSI Swap = ",rsi_swap);

      if(SymbolUsed[a]) rsi_swap=false;

      //---- sell conditions
      if(rsi_swap && stoch_sell)
        {
         take = bid_price - ((tp + (2*dp))* points);
         stop = ask_price + (sl * points);
         res=OrderSend(Check_Symbol,OP_SELL,Lot,bid_price,3,stop,take,NULL,MAGICMA,0,Red);
         if(res)
           {
            FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+DoubleToStr(AccountNumber(),0)+" Symbol="+Check_Symbol+" Event=New_Trade TicketNumber="+DoubleToStr(res,0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5));
            TidyUpTrades();
           }
        }
      //---- buy conditions
      if(rsi_swap && stoch_buy)
        {
         take = ask_price + ((tp + (2*dp))* points);
         stop = bid_price - (sl * points);
         res=OrderSend(Check_Symbol,OP_BUY,Lot,ask_price,3,stop,take,NULL,MAGICMA,0,Green);
         if(res)
           {
            FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+DoubleToStr(AccountNumber(),0)+" Symbol="+Check_Symbol+" Event=New_Trade TicketNumber="+DoubleToStr(res,0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5));
            TidyUpTrades();
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForClose()
  {

   for(int i=0;i<=OrdersTotal();i++)
     { //1

      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
        {

         Check_Symbol=OrderSymbol();

         ask_price = MarketInfo(Check_Symbol,MODE_ASK);
         bid_price = MarketInfo(Check_Symbol,MODE_BID);
         points=MarketInfo(Check_Symbol,MODE_POINT);

         int tkt_number=OrderTicket();
         int found_tkt=-1;
         int found_posn=-1;
         for(int find_tkt=0;find_tkt<=open_tickets;find_tkt++)
           {
            if(open_trades[find_tkt]==tkt_number)
              {
               found_posn=find_tkt;
              };
           }

         if(found_posn<0)
           {
            Print("Not seen - ",tkt_number," before ");
            TidyUpTrades();
            continue;
           }
         tkt=found_posn;
         found_tkt=open_trades[tkt];
         //Print("tkt=",tkt," -  found_tkt=",found_tkt);

         order_exists[tkt]=true;

         current_profit[tkt]=(OrderProfit()/OrderLots());  // profit in points

         if(tkt_open[tkt]==0) tkt_open[tkt]=ask_price;
         tkt_close[tkt]=ask_price;

         bool gone_up=false;

         if(close_up && instant_close==true)
           { //2
            trades_won++;
            if(OrderType()==OP_BUY)
              { //3
               res=OrderClose(OrderTicket(),OrderLots(),bid_price,3,Blue);
               //        Print("Order ",tkt2," closed at ",current_profit[tkt2]);
              } //3
            if(OrderType()==OP_SELL)
              { //3
               res=OrderClose(OrderTicket(),OrderLots(),ask_price,3,Blue);
               //      Print("Order ",tkt2," closed at ",current_profit[tkt2]);
              } //3
            break;
           } //2

         if(close_up && (trigger_reached[tkt]==false || OrderStopLoss()==0) && instant_close!=true)
           {
            gone_up=true;
            trigger_reached[tkt]=true;
            f_profit[tkt]=(current_profit[tkt]-2);
            Print("CloseUp : Triggered TP/SL on ",found_tkt);
           }

         if(current_profit[tkt]>f_profit[tkt])
           { //2
            if(f_profit[tkt]>=trigger_profit+drop_profit) trigger_reached[tkt]=true;

            //Print("tkt=",tkt," Ticket=",found_tkt," - Trigger reached=",trigger_reached[tkt],"         fprofit=",f_profit[tkt],"        current=",current_profit[tkt]," tigger_level=",trigger_profit+drop_profit);

            f_profit[tkt]=current_profit[tkt];
            gone_up=true;

            if(gone_up && trigger_reached[tkt]==true)
              { //3
               if(OrderType()==OP_BUY)
                 { //4
                  take = ask_price + (dp * points );
                  stop = bid_price - (dp * points);
                  res=OrderModify(found_tkt,bid_price,stop,take,8,Red);
                  if(res)
                    {
                     order_points=(OrderProfit()/OrderLots());
                     //Print("Modify - ",tkt);
                     FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+DoubleToStr(AccountNumber(),0)+" Symbol="+OrderSymbol()+" Event=Modify_Trade TicketNumber="+DoubleToStr(found_tkt,0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Points="+DoubleToStr(order_points,2));
                       } else {
                     Print("Order modify failed on buy tkt ",found_tkt);
                    }
                 } //4
               if(OrderType()==OP_SELL)
                 { //4
                  take = bid_price - (dp * points );
                  stop = ask_price + (dp * points);
                  res=OrderModify(found_tkt,ask_price,stop,take,8,Green);
                  if(res)
                    {
                     order_points=(OrderProfit()/OrderLots());
                     //Print("Modify - ",tkt);
                     FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+DoubleToStr(AccountNumber(),0)+" Symbol="+OrderSymbol()+" Event=Modify_Trade TicketNumber="+DoubleToStr(found_tkt,0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Points="+DoubleToStr(order_points,2));
                       } else {
                     Print("Order modify failed on sell tkt ",found_tkt);
                    }
                 } //4
              } //3
           }
        }
     } //1
  } // end void
//+------------------------------------------------------------------+
//|     Close all trades instantly                                   |
//+------------------------------------------------------------------+
void closeAll()
  {
   for(int t=0;t<=OrdersTotal();t++)
     {
      res=OrderSelect(t,SELECT_BY_POS);
      if(OrderType()==OP_BUY)
        { //3
         res=OrderClose(OrderTicket(),OrderLots(),bid_price,3,Blue);
         //        Print("Order ",tkt2," closed at ",current_profit[tkt2]);
        } //3
      if(OrderType()==OP_SELL)
        { //3
         res=OrderClose(OrderTicket(),OrderLots(),ask_price,3,Blue);
         //      Print("Order ",tkt2," closed at ",current_profit[tkt2]);
        } //3
     }

  }
//+------------------------------------------------------------------+
//| export all trades function                                       |
//+------------------------------------------------------------------+

void ExportTrades()
  {
   FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+DoubleToStr(AccountNumber(),0)+" Event=Report Equity="+DoubleToStr(simEquity(),2)+" CloseUp="+DoubleToStr(CloseOutPrice,2)+" FreeMargin="+DoubleToStr(simMargin(),2)+" MinEquity="+DoubleToStr(EquityCheck,2)+" Deposits="+DoubleToStr(Deposits,2)+" Withdrawls="+DoubleToStr(Withdrawls,2)+" RealEquity="+DoubleToStr(AccountEquity(),2)+" Version="+DoubleToStr(version*100,0));
//Print("Equity=",DoubleToStr(simEquity(),2)," Deposits=",DoubleToStr(Deposits,2)," Withdrawls=",DoubleToStr(Withdrawls,2));
   for(int t=0;t<=OrdersTotal();t++)
     {
      res=OrderSelect(t,SELECT_BY_POS);
      if(res)
        {
         order_points=(OrderProfit()/OrderLots());
         FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+DoubleToStr(AccountNumber(),0)+" Symbol="+OrderSymbol()+" Event=Existing_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Points="+DoubleToStr(order_points,2));
         for(int c=0;c<ArraySize(SymbolPairs); c++)
           {
            if(OrderSymbol()==SymbolPairs[c])
              {
               SymbolUsed[c]=true;
              }
           }
        }
     }
   if(oldHistoryTotal!=OrdersHistoryTotal())
     {
      for(int u=0;u<OrdersHistoryTotal();u++)
        {
         //Print("historical orders = ",OrdersHistoryTotal(), " writing no. ",u);
         res=OrderSelect(u,SELECT_BY_POS,MODE_HISTORY);
         if(res)
           {
            FileWrite(handle,"Time="+DoubleToStr(correctTime(OrderCloseTime()),0)+" Account="+DoubleToStr(AccountNumber(),0)+" Symbol="+OrderSymbol()+" Event=Closed_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" ClosePrice="+DoubleToStr(OrderClosePrice(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Commission="+DoubleToStr(OrderCommission(),2));
           }
        }
     }
   oldOrdersTotal=OrdersTotal();
   oldHistoryTotal=OrdersHistoryTotal();
   oldMaxTicket=highest_ticket;

   if(!IsTesting()) FileFlush(handle);
   return;
  }
//+------------------------------------------------------------------+
//|   sort out the incorrect epoch                                   |
//+------------------------------------------------------------------+
double correctTime(double time_value)
  {
// for some reason all epoch times are 2 hours ahead..... Seriously, how can you get epoch wrong..
   int difference=(int)(TimeCurrent()-TimeGMT());
   return time_value-(difference);
// European summer time, 3 hours ahead
//   return time_value-(3600*3);
  }
//+------------------------------------------------------------------+
//| tidy up trades function                                          |
//+------------------------------------------------------------------+

int TidyUpTrades()
  {
   for(int c=0;c<ArraySize(SymbolPairs); c++)
     {
      SymbolUsed[c]=false;
     }

   for(int t=0;t<=OrdersTotal();t++)
     {
      res=OrderSelect(t,SELECT_BY_POS);
      if(res)
        {
         int tkt_number=OrderTicket();
         int found_tkt=-1;
         int found_posn=-1;
         for(int find_tkt=0;find_tkt<=open_tickets;find_tkt++)
           {
            if(open_trades[find_tkt]==tkt_number)
              {
               found_posn=find_tkt;
              };
           }
         if(found_posn<0)
           {
            open_tickets=open_tickets+1;
            open_trades[open_tickets]=OrderTicket();
            Print("New Ticket - ",open_tickets," - ",OrderTicket());
           }
        }
     }
   return(0);
  }
//+------------------------------------------------------------------+
//| expert initialization function                                 |
//+------------------------------------------------------------------+


void OnInit()
  {
   suffix=StringSubstr(_Symbol,7,1);
   if(IsTesting())
     {
      ArrayResize(SymbolPairs,1);
      SymbolPairs[0]=_Symbol;
      suffix="";
     }

   filename="Tickets_"+DoubleToStr(AccountNumber(),0)+".log";
   handle=FileOpen(filename,FILE_CSV|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_CSV);

   Print("filename = ",filename,",  handle = ",handle);

   StartBalance=AccountBalance()-bufferEquity;

   reinit();

   TidyUpTrades();

   return;
  }
//+------------------------------------------------------------------+
//| expert reinitialization function                                 |
//+------------------------------------------------------------------+

int reinit()
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

// contact mothership for instructions
// expecting a csv string of CloseUp, Withdrawls,Deposits

   string acctUrl="http://kmug.ddns.net/elpheba/"+DoubleToStr(AccountNumber(),0)+"/start/";

   string instructions=GrabWeb(acctUrl,simEquity());
   instructions=StringTrimRight(StringTrimLeft(instructions));

   string sep=",";                // A separator as a character
   ushort u_sep;                  // The code of the separator character
   string result[];               // An array to get strings
//--- Get the separator code
   u_sep=StringGetCharacter(sep,0);
//--- Split the string to substrings
   int k=StringSplit(instructions,u_sep,result);
//--- Show a comment
   PrintFormat("Strings obtained: %d. Used separator '%s' with the code %d",k,sep,u_sep);
//--- Now output all obtained strings
   if(k>0)
     {
      for(int i=0;i<k;i++)
        {
         printf("result[%d]=%s",i,result[i]);
         result[i]=(string) result[i];
        }
     }

   if(k==3)
     {
      CloseOutPrice=(double) result[0];
      Withdrawls=(double) result[1];
      Deposits=(double) result[2];
     }

   bNewBar();
   bNewWeek();
   bNewMin();

   if(k!=3)
     {

      Print("No repsonse from mothership - pausing 15 minutes before retry");
      Sleep(900000);
      reinit();

     }
   increaseTarget=simBalance()*0.01;
   EquityCheck=simEquity()*0.85;
   LotPrice=(simEquity()/300);

   symbol_profit=0;
   Lot=NormalizeDouble(LotPrice/100,2);
   if(Lot<0.01) Lot=0.01;

   oldOrdersTotal=-1;
   oldHistoryTotal=-1;
   oldMaxTicket=-1;
   trigger_profit=tp;
   drop_profit=dp;
   stop_loss=sl;
   close_up=false;
   Print("CloseOutPrice=",CloseOutPrice,"  LotPrice=",LotPrice,"  Lot=",Lot,"  trigger_profit=",trigger_profit,"  drop_profit=",drop_profit);
   FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+DoubleToStr(AccountNumber(),0)+" Event=Initialize Equity="+DoubleToStr(simEquity(),2)+" CloseUp="+DoubleToStr(CloseOutPrice,2)+" IncreaseTarget="+DoubleToStr(increaseTarget,2));
   if(!IsTesting()) FileFlush(handle);

   return(0);
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
   if(bM1 && !close_up && !IsTesting())
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
     }

   if(simEquity()>CloseOutPrice && !close_up && closeTrades)
     {
      close_up=true;
      SendNotification("Close up reached @ "+DoubleToStr(simEquity(),2));
      Print("***** Close out price reached, ",simEquity()," ********");
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+DoubleToStr(AccountNumber(),0)+" Event=CloseUp_Triggered Equity="+DoubleToStr(simEquity(),2));
      if(!IsTesting()) FileFlush(handle);
     }
   if(close_up && OrdersTotal()==0)
     {
      Print("****** Close out completed, balance=",simBalance()," ***********");
      close_up=false;
      SendNotification("Close up completed @ "+DoubleToStr(simEquity(),2));
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+DoubleToStr(AccountNumber(),0)+" Event=CloseUp_Complete Equity="+DoubleToStr(simEquity(),2));
      if(!IsTesting()) FileFlush(handle);
      double bankIt=simEquity()-CloseOutPrice;
      if(bankIt<0) bankIt=0;
      //Print("Withdraw to bank - ",bankIt);
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+DoubleToStr(AccountNumber(),0)+" Event=Withdrawl Withdrawl="+DoubleToStr(bankIt,2));

      string sendUrl="http://kmug.ddns.net/elpheba/"+DoubleToStr(AccountNumber(),0)+"/completed/"+DoubleToStr((simEquity()*100),0);
      string sendWithdrawl=(GrabWeb(sendUrl,simEquity()));

      //Print("Web request - ",sendUrl);
      Sleep(300000); // pause 5 minutes to let mothership update
      reinit();
     }

   if(OrdersTotal()==0 && simBalance()<EquityCheck) reinit();

   if(OrdersTotal()>0 && closeTrades) CheckForClose();

   if(bM1) ExportTrades();

   if(bNB && !close_up && openTrades && OrdersTotal()<max_trades && simMargin()>EquityCheck) CheckForOpen(); // This is more conservative as it takes into account moneys used in the trade itself.

   if(!IsTesting()) FileFlush(handle);

  }
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
