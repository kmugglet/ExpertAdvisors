//+------------------------------------------------------------------+
//|                                   Elpheba-20131218-MultiPair.mq4 |
//|                                        Copyright 2012, Codatrek. |
//|                                           http://www.codatek.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012, Codatrek."
#property link      "http://www.codatrek.com"

/*  "HIGH RISK WARNING: Foreign exchange trading carries a high level of risk that may not be suitable for all investors. 
   Leverage creates additional risk and loss exposure. 
   Before you decide to trade foreign exchange, carefully consider your investment objectives, experience level, and risk tolerance. 
   You could lose some or all of your initial investment; do not invest money that you cannot afford to lose. 
   Educate yourself on the risks associated with foreign exchange trading, and seek advice from an independent financial or tax advisor if you have any questions. 
   Any data and information is provided 'as is' solely for informational purposes, and is not intended for trading purposes or advice."
*/

double    LotPrice=1; // baby steps
//--- input parameters
extern double    BuyPoint=30;
extern double    SellPoint=70;
extern double    tp = 300;
extern double    dp = 30;
extern double    sl = 7500;
extern int       max_trades=8; // max trades per symbol pair

int      tkt,tkt2,lowest_ticket,highest_ticket;

double   take,stop;
double   CloseOutPrice,EquityCheck,order_points;
int      RSIperiod=14;
int      AppliedPrice=4;
double   trigger_profit;
double   drop_profit;
double   stop_loss;
double   closing_start, closing_end;
double   ask_price,bid_price,points,ask_p,bid_p,pts;
string   Check_Symbol,suffix="i";
int      SymbolOrders=0;
int      MAGICMA;
int      trades_won=0;
int      oldOrdersTotal=0,oldHistoryTotal=0,oldMaxTicket=0;

double   Lot,StartBalance,Withdrawls,WeeklyWithdrawl;
bool     rsi_swap=true;
bool     this_rsi,last_rsi,stoch_buy,stoch_sell,close_up=false,close_email=false,bNB,bM1,bW1;
bool     ma_close,profit_close[9999999],trigger_reached[9999999],order_exists[9999999],res;
double   current_profit[9999999],tkt_open[9999999],tkt_high[9999999],tkt_low[9999999],tkt_close[9999999];
int      hedge_tkt[9999999],h_tkt;
double   symbol_profit;
double   f_profit[9999999];
double   RSIprev;
int      open_trades[100];
double   iStochvalue=0;
double   RSInow,RSIlast;

string   filename;
int      handle,st;
string   order[]={"Buy","Sell"};
datetime LastTick[20]; // same number as symbol pairs or greater
datetime TimeNow;
string   SymbolPairs[]=
  {
   "EURUSD","EURGBP","GBPUSD",
   "AUDUSD","EURJPY","AUDJPY",
   "EURAUD","USDCAD","USDJPY",
   "GBPCAD","AUDCAD","USDCHF",
   "GBPAUD","XAUUSD"
  };
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
bool       bNewMin()
  {

   static int iTime_1=0;

   if(iTime_1<iTime(NULL,PERIOD_M1,0))
     { iTime_1=iTime(NULL,PERIOD_M1,0); return(TRUE); }
   else     { return(FALSE); }

  }
//+------------------------------------------------------------------+
bool       bNewWeek()
  {

   static int iTime_1=0;

   if(iTime_1<iTime(NULL,PERIOD_W1,0))
     { iTime_1=iTime(NULL,PERIOD_W1,0); return(TRUE); }
   else     { return(FALSE); }

  }
//+------------------------------------------------------------------+
bool       bNewBar()
  {

   static int iTime_0=0;

   if(iTime_0<iTime(NULL,NULL,0))
     { iTime_0=iTime(NULL,NULL,0); return(TRUE); }
   else     { return(FALSE); }

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
      Print(Check_Symbol," : Stoch - ",iStochvalue,"RSI Swap = ",rsi_swap);

      if(open_trades[a]>=max_trades) rsi_swap=false;

      //---- sell conditions
      if(rsi_swap && stoch_sell)
        {
         take = bid_price - ((tp + (2*dp))* points);
         stop = ask_price + (sl * points);
         res=OrderSend(Check_Symbol,OP_SELL,Lot,bid_price,3,NULL,take,NULL,MAGICMA,0,Red);
         if (res) FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Symbol="+Check_Symbol+" Event=New_Trade TicketNumber="+DoubleToStr(res,0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5));
        }
      //---- buy conditions
      if(rsi_swap && stoch_buy)
        {
         take = ask_price + ((tp + (2*dp))* points);
         stop = bid_price - (sl * points);
         res=OrderSend(Check_Symbol,OP_BUY,Lot,ask_price,3,NULL,take,NULL,MAGICMA,0,Green);
         if (res) FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Symbol="+Check_Symbol+" Event=New_Trade TicketNumber="+DoubleToStr(res,0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5));
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

         tkt=OrderTicket()-lowest_ticket;
         if(tkt<0) tkt=0;
         if(lowest_ticket==0 && !IsTesting())
           { //2
            lowest_ticket=tkt-1;
            tkt=OrderTicket()-lowest_ticket;
           } //2

         if(IsTesting()) lowest_ticket=0;

         if(tkt>highest_ticket) highest_ticket=tkt;

         order_exists[tkt]=true;

         current_profit[tkt]=(OrderProfit()/OrderLots());  // profit in points

         if(tkt_open[tkt]==0) tkt_open[tkt]=ask_price;
         tkt_close[tkt]=ask_price;

         bool gone_up=false;

         if(close_up && (trigger_reached[tkt]==false || OrderStopLoss()==0))
           {
            gone_up=true;
            trigger_reached[tkt]=true;
            f_profit[tkt]=(current_profit[tkt]-2);
            Print("CloseUp : Triggered TP/SL on ",tkt);
           }
         if(current_profit[tkt]>f_profit[tkt])
           { //2
            if(f_profit[tkt]>=trigger_profit+drop_profit) trigger_reached[tkt]=true;
            f_profit[tkt]=current_profit[tkt];
            gone_up=true;

            if(gone_up && trigger_reached[tkt]==true)
              { //3
               if(OrderType()==OP_BUY)
                 { //4
                  take = ask_price + (dp * points );
                  stop = bid_price - (dp * points);
                  res=OrderModify(OrderTicket(),bid_price,stop,take,8,Red);
                  if(res)
                    {
                     order_points=(OrderProfit()/OrderLots());
                     FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Symbol="+OrderSymbol()+" Event=Modify_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Points="+DoubleToStr(order_points,2));
                       } else {
                     Print("Order modify failed on buy tkt ",tkt);
                    }
                 } //4
               if(OrderType()==OP_SELL)
                 { //4
                  take = bid_price - (dp * points );
                  stop = ask_price + (dp * points);
                  res=OrderModify(OrderTicket(),ask_price,stop,take,8,Green);
                  if(res)
                    {
                     order_points=(OrderProfit()/OrderLots());
                     FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Symbol="+OrderSymbol()+" Event=Modify_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Points="+DoubleToStr(order_points,2));
                       } else {
                     Print("Order modify failed on sell tkt ",tkt);
                    }
                 } //4
              } //3
           }
        }
     } //1
  } // end void
//+------------------------------------------------------------------+
//| export all trades function                                       |
//+------------------------------------------------------------------+

void ExportTrades()
  {
   FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+AccountNumber()+" Event=Report Equity="+DoubleToStr(simEquity(),2)+" CloseUp="+DoubleToStr(CloseOutPrice,2)+" FreeMargin="+DoubleToStr(simMargin(),2)+" MinEquity="+DoubleToStr(EquityCheck,2));

   for(int t=0;t<=OrdersTotal();t++)
     {
      res=OrderSelect(t,SELECT_BY_POS);
      if(res)
        {
         order_points=(OrderProfit()/OrderLots());
         FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Symbol="+OrderSymbol()+" Event=Existing_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Points="+DoubleToStr(order_points,2));
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
            FileWrite(handle,"Time="+DoubleToStr(correctTime(OrderCloseTime()),0)+" Symbol="+OrderSymbol()+" Event=Closed_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" ClosePrice="+DoubleToStr(OrderClosePrice(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Commission="+DoubleToStr(OrderCommission(),2));
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
//|                                                                  |
//+------------------------------------------------------------------+
double correctTime(double time_value)
  {
// for some reason all epoch times are 2 hours ahead..... Seriously, how can you get epoch wrong..
   return time_value-(3600*2);
  }
//+------------------------------------------------------------------+
//| tidy up trades function                                 |
//+------------------------------------------------------------------+

int TidyUpTrades()
  {
   for(int t=0;t<=highest_ticket;t++)
     {
      order_exists[t]=OrderSelect(lowest_ticket+t,SELECT_BY_TICKET);
      if(OrderCloseTime()!=0)
        {
         order_exists[t]=false;
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

   filename="Tickets_"+AccountNumber()+".log";
   handle=FileOpen(filename,FILE_CSV|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_CSV);

   Print("filename = ",filename,",  handle = ",handle);

   StartBalance=AccountBalance();
   Withdrawls=0.00;
   WeeklyWithdrawl=simBalance()/100;

   reinit();

   return;
  }
//+------------------------------------------------------------------+
//| expert reinitialization function                                 |
//+------------------------------------------------------------------+

int reinit()
  {
   for(int f=0;f<=9999997;f++)
     {
      profit_close[f]=false;
      trigger_reached[f]=false;
      order_exists[f]=false;
      current_profit[f]=0.0;
      tkt_open[f]=0.0;
      tkt_close[f]= 0.0;
      tkt_high[f] = 0.0;
      tkt_low[f]=100000.0;
      hedge_tkt[f]= 0;
      f_profit[f] = 0.0;
     }
// 2% increase 
   CloseOutPrice=simBalance()*1.01;
   EquityCheck=simEquity()*0.85;
   LotPrice=(simEquity()/200);

   symbol_profit=0;
   Lot=NormalizeDouble(LotPrice/100,2);
   if(Lot<0.01) Lot=0.01;

   MAGICMA=(CloseOutPrice*100);
   highest_ticket=0;
   bNewBar();
   bNewWeek();

   for(int j=0;j<OrdersTotal();j++)
     { //1
      res=OrderSelect(j,SELECT_BY_POS);
      if(res) 
        {
         if(OrderTicket()<lowest_ticket) lowest_ticket=OrderTicket();
         if(OrderMagicNumber()<MAGICMA && OrderMagicNumber()!=24771442) MAGICMA=OrderMagicNumber();
         if(lowest_ticket==0) lowest_ticket=OrderTicket();
        }
     }
   Print("MAGICMA - ",MAGICMA," CloseOutPrice - ",CloseOutPrice);
   CloseOutPrice=MAGICMA/100;
   Print("MAGICMA - ",MAGICMA," CloseOutPrice - ",CloseOutPrice);

   oldOrdersTotal=-1;
   oldHistoryTotal=-1;
   oldMaxTicket=-1;
   trigger_profit=tp;
   drop_profit=dp;
   stop_loss=sl;
   close_up=false;
   Print("CloseOutPrice=",CloseOutPrice,"  LotPrice=",LotPrice,"  Lot=",Lot,"  trigger_profit=",trigger_profit,"  drop_profit=",drop_profit);
   FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+AccountNumber()+" Event=Initialize Equity="+DoubleToStr(simEquity(),2)+" CloseUp="+DoubleToStr(CloseOutPrice,2));
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

   if(simEquity()>CloseOutPrice && !close_up)
     {
      close_up=true;
      closing_start = simEquity();
      SendNotification("Close up reached @ "+DoubleToStr(simEquity(),2));
      Print("***** Close out price reached, ",simEquity()," ********");
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+AccountNumber()+" Event=Close_Triggered Equity="+simEquity());
      if(!IsTesting()) FileFlush(handle);
     }
   if(close_up && OrdersTotal()==0)
     {
      Print("****** Close out completed, balance=",simBalance()," ***********");
      close_up=false;
      closing_end = simEquity();
      SendNotification("Close up completed @ "+DoubleToStr(simEquity(),2));
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+AccountNumber()+" Event=Close_Complete Equity="+simEquity())+" Closing_Start="+closing_start+" Closing_End="+closing_end;
      if(!IsTesting()) FileFlush(handle);
      reinit();
     }

   if(OrdersTotal()==0 && simBalance()<EquityCheck) reinit();

   CheckForClose();

   if(bM1) TidyUpTrades();

   if(bM1) ExportTrades();

   if(bNB && !close_up && OrdersTotal()>max_trades) Print("Max trades opened already");
   else if(bNB && !close_up && simMargin()<EquityCheck) Print("Insufficient Margin");
   else if(bNB && !close_up && OrdersTotal()<max_trades && simMargin()>EquityCheck) CheckForOpen();
//   if(bNB && !close_up && OrdersTotal()<max_trades && simEquity()>EquityCheck) CheckForOpen();

   if(simEquity()<0) Print("STOP OUT");
   if(!IsTesting()) FileFlush(handle);

   if(bW1)
     {
      Withdrawls=Withdrawls+WeeklyWithdrawl;
      Print("Withdrawls : ",WeeklyWithdrawl,", Total Taken: ",Withdrawls,", simBalance : ",simBalance(),", simEquity : ",simEquity());
     };

  }
//+------------------------------------------------------------------+

double simEquity()
  {

   double Equity=AccountEquity()-Withdrawls;

   return Equity;
  }
//+------------------------------------------------------------------+
double simBalance()
  {

   double Balance=AccountBalance()-Withdrawls;

   return Balance;
  }
//+------------------------------------------------------------------+
double simMargin()
  {

   double Margin=AccountFreeMargin()-Withdrawls;

   return Margin;
  }
//+------------------------------------------------------------------+
