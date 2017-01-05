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

double    LotPrice = 1; // baby steps
//--- input parameters
extern double    BuyPoint=25;
extern double    SellPoint=75;
extern double    tp = 200;
extern double    dp = 50;
extern double    sl = 7500;
extern int       max_trades = 50; // max trades per symbol pair

int      tkt,tkt2,lowest_ticket, highest_ticket;

double   take,stop;
double   CloseOutPrice,EquityCheck;
int      RSIperiod=14;
int      AppliedPrice=4;
double   trigger_profit;
double   drop_profit;
double   stop_loss;
double   ask_price, bid_price, points,ask_p,bid_p,pts;
string   Check_Symbol,suffix = "i";
int      SymbolOrders = 0;
int      MAGICMA = 22300;
int      trades_won = 0;
int      oldOrdersTotal = 0,oldHistoryTotal = 0, oldMaxTicket =0;

double   Lot;
bool     rsi_swap = true;
bool     this_rsi,last_rsi,stoch_buy,stoch_sell,close_up=false,close_email=false, bNB, bM1;
bool     ma_close, profit_close[999999], trigger_reached[999999], order_exists[999999], res;
double   current_profit[999999],tkt_open[999999], tkt_high[999999],tkt_low[999999],tkt_close[999999];
int      hedge_tkt[999999],h_tkt;
double   symbol_profit;
double   f_profit[999999];
double   RSIprev;
int      open_trades[100];
double   iStochvalue = 0;
double   RSInow, RSIlast;

string   filename;
int      handle, st;
string   order[] = {"Buy","Sell"};
datetime LastTick[20]; // same number as symbol pairs or greater
datetime TimeNow;
string   SymbolPairs[] = {"EURUSD","EURGBP","GBPUSD",
                           "AUDUSD","EURJPY","AUDJPY",
                           "EURAUD","USDCAD","USDJPY",
                           "GBPCAD","AUDCAD", "USDCHF",
                           "GBPAUD", "XAUUSD"
                          };

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
//////////////////////////////////////////////////////////////////<          >
bool       bNewMin ()                                           //<          >
{                                                               //<          >
//                                                              //<          >
static int iTime_1 = 0                                        ; //<          >
//                                                              //<          >
if       ( iTime_1 < iTime ( NULL , PERIOD_M1 , 0 ) )              //<          >
         { iTime_1 = iTime ( NULL , PERIOD_M1 , 0 ) ; return ( TRUE  ) ; }   // >
else     {                                 return ( FALSE ) ; } //<          >
//                                                              //<          >
}                                                               //<          >
//////////////////////////////////////////////////////////////////<          >
bool       bNewBar ()                                           //<          >
{                                                               //<          >
//                                                              //<          >
static int iTime_0 = 0                                        ; //<          >
//                                                              //<          >
if       ( iTime_0 < iTime ( NULL , NULL , 0 ) )                      //<          >
         { iTime_0 = iTime ( NULL , NULL , 0 ) ; return ( TRUE  ) ; } //<          >
else     {                                 return ( FALSE ) ; } //<          >
//                                                              //<          >
}                                                               //<          >
//////////////////////////////////////////////////////////////////<          >
void CheckForOpen()
  {
   //----
   //-----------------------------------------------------------------
   // Bar checks
   //-----------------------------------------------------------------

   for(int a = 0; a < ArraySize(SymbolPairs); a++)
    {
      Check_Symbol = SymbolPairs[a] + suffix;
      //Print("Checking ",Check_Symbol);
      //if(Check_Symbol != Symbol()) break;
      ask_price = MarketInfo(Check_Symbol,MODE_ASK);
      bid_price = MarketInfo(Check_Symbol,MODE_BID);
      points = MarketInfo(Check_Symbol,MODE_POINT);

      RSInow=iRSI(Check_Symbol,NULL,RSIperiod,AppliedPrice,0);
      RSIlast=iRSI(Check_Symbol,NULL,RSIperiod,AppliedPrice,1);

      iStochvalue= iStochastic(Check_Symbol,NULL,5,3,3,MODE_SMMA,1,MODE_MAIN,1);

      last_rsi = false;
      this_rsi = false;
      stoch_sell = false;
      stoch_buy = false;
      last_rsi = (RSIlast > 50);
      this_rsi = (RSInow > 50);
      rsi_swap=(last_rsi!=this_rsi);
      Print(Check_Symbol, " : Stoch - ",iStochvalue, "RSI Swap = ",rsi_swap);
   //   rsi_swap=(true);
      //Print("Check Open");
      if(iStochvalue < BuyPoint)
         {
            stoch_buy = true;
         }
      if(iStochvalue > SellPoint)
         {
            stoch_sell = true;
         }

      if(open_trades[a] >= max_trades) rsi_swap = false;

   //---- sell conditions
      if(rsi_swap && stoch_sell)
        {
         take = bid_price - (tp * points * 3);
         stop = ask_price + (sl * points);
         res=OrderSend(Check_Symbol,OP_SELL,Lot,bid_price,3,NULL,take,"",MAGICMA,0,Red);
        }
   //---- buy conditions
      if(rsi_swap && stoch_buy)
        {
         take = ask_price + (tp * points * 3);
         stop = bid_price - (sl * points);
         res=OrderSend(Check_Symbol,OP_BUY,Lot,ask_price,3,NULL,take,"",MAGICMA,0,Green);
        }

   }
//----
}



void CheckForClose()
  {
   //----
   //Print("Check ..");
 

   SymbolOrders = 0;

   for(int i=0;i<=OrdersTotal();i++)
      { //1
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)        break;

         
         if(OrderType()<2) SymbolOrders++;
         //---- check order type

         Check_Symbol = OrderSymbol();
         
         ask_price = MarketInfo(Check_Symbol,MODE_ASK);
         bid_price = MarketInfo(Check_Symbol,MODE_BID);
         points = MarketInfo(Check_Symbol,MODE_POINT);

         tkt = OrderTicket() - lowest_ticket;
         if(lowest_ticket == 0 && !IsTesting())
            { //2
               lowest_ticket = tkt - 1;
               tkt = OrderTicket() - lowest_ticket;
            } //2

         if(IsTesting()) lowest_ticket = 0;

         if(tkt > highest_ticket) highest_ticket = tkt;

         order_exists[tkt] = true;

         current_profit[tkt] = (OrderProfit()/OrderLots());  // profit in points
         
         if(tkt_open[tkt] == 0) tkt_open[tkt] = ask_price;
         tkt_close[tkt] = ask_price;
               
         bool gone_up =  false;
         if(current_profit[tkt] > f_profit[tkt])
            { //2
               f_profit[tkt] = current_profit[tkt];
               gone_up = true;
               //Print("Profit peak increased on order ",tkt," @ ",f_profit[tkt]);
            } //2
         //Print("tkt ",tkt," low tickt ",lowest_ticket," current : ",current_profit[tkt]," f_profit : ",f_profit[tkt],"OP : ", OrderProfit()," OL : ",OrderLots()," Points ",(OrderProfit()/OrderLots()));

         if(f_profit[tkt] > trigger_profit + drop_profit)
            { //2
               if(!trigger_reached[tkt]) Print("Hit trigger on order ",tkt + lowest_ticket);
               if(gone_up)
                  { //3
        //             Print("Order ",tkt + lowest_ticket," points increased to ",DoubleToStr(f_profit[tkt],0));
                     if(OrderType()==OP_BUY)
                       { //4
                        take = ask_price + (trigger_profit * points * 3);
                        stop = bid_price - (drop_profit * points);
                        res=OrderModify(OrderTicket(),bid_price,stop,take,3,Red);
                       } //4
                     if(OrderType()==OP_SELL)
                       { //4
                        take = bid_price - (trigger_profit * points * 3);
                        stop = ask_price + (drop_profit * points);
                        res=OrderModify(OrderTicket(),ask_price,stop,take,3,Green);
                       } //4
                  } //3
               trigger_reached[tkt] = true;
            } //2

            if(close_up && trigger_reached[tkt]==false)
               { //2
                  trigger_reached[tkt]=true;
                  f_profit[tkt]=current_profit[tkt];
               } //2

            profit_close[tkt] = false;
            if(close_up) profit_close[tkt]=true;

            if(current_profit[tkt] < (f_profit[tkt] - dp) && trigger_reached[tkt]) {profit_close[tkt] = true;}

   } //1

   //Print("Highest Ticket : ",highest_ticket);


   for(int j=0;j<=OrdersTotal();j++)
      { //1
         if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
         //if(OrderSymbol()!=Symbol()) continue;

         tkt2 = OrderTicket() - lowest_ticket;
         Check_Symbol = OrderSymbol();
         
         ask_price = MarketInfo(Check_Symbol,MODE_ASK);
         bid_price = MarketInfo(Check_Symbol,MODE_BID);
         points = MarketInfo(Check_Symbol,MODE_POINT);


         if(profit_close[tkt2])
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
            } //2
      } //1

      

} // end void


//+------------------------------------------------------------------+
//| export all trades function                                       |
//+------------------------------------------------------------------+

void OnTimer()
{
   for(int xx = 0; xx < ArraySize(SymbolPairs); xx++)
      {
         open_trades[xx] = 0;
         Check_Symbol= SymbolPairs[xx]+suffix;        
         ask_p = MarketInfo(Check_Symbol,MODE_ASK);
         bid_p = MarketInfo(Check_Symbol,MODE_BID);
         pts = MarketInfo(Check_Symbol,MODE_POINT);
         TimeNow = TimeCurrent();
         if(TimeNow>LastTick[xx]) { // only write info if it has changed 
            Print("Time="+DoubleToStr(TimeNow,0)+" Symbol="+Check_Symbol+" Event=TICK Bid="+DoubleToStr(bid_p,5)+" Ask="+DoubleToStr(ask_p,5)) ;
            FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeNow),0)+" Symbol="+Check_Symbol+" Event=TICK Bid="+DoubleToStr(bid_p,5)+" Ask="+DoubleToStr(ask_p,5)) ;
            LastTick[xx] = TimeNow;
         }
      }

   FileFlush(handle);
   return;
}

void ExportTrades()
{
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Account="+AccountNumber()+" Event=Report Equity="+DoubleToStr(AccountEquity(),2)+" CloseUp="+DoubleToStr(CloseOutPrice,2)) ;

      for(int t = 0;t<=OrdersTotal();t++) {
         res = OrderSelect(t,SELECT_BY_POS);
         if(res) {
            FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),3)+" Symbol="+OrderSymbol()+" Event=Open_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" TP="+DoubleToStr(OrderTakeProfit(),5)+" SL="+DoubleToStr(OrderStopLoss(),5)+" Profit="+DoubleToStr(OrderProfit(),2)) ;
         }
      }
 
   if(oldHistoryTotal!=OrdersHistoryTotal()) {
      for(int u = 0;u<OrdersHistoryTotal();u++) {
         //Print("historical orders = ",OrdersHistoryTotal(), " writing no. ",u);
         res = OrderSelect(u,SELECT_BY_POS,MODE_HISTORY);
         if(res) {
            FileWrite(handle,"Time="+DoubleToStr(correctTime(OrderCloseTime()),0)+" Symbol="+OrderSymbol()+" Event=Closed_Trade TicketNumber="+DoubleToStr(OrderTicket(),0)+" OrderType="+DoubleToStr(OrderType(),0)+" OpenPrice="+DoubleToStr(OrderOpenPrice(),5)+" Lots="+DoubleToStr(OrderLots(),2)+" ClosePrice="+DoubleToStr(OrderClosePrice(),5)+" Profit="+DoubleToStr(OrderProfit(),2)+" Commission="+DoubleToStr(OrderCommission(),2)) ;
         }
      }
   }
   oldOrdersTotal = OrdersTotal();
   oldHistoryTotal = OrdersHistoryTotal();
   oldMaxTicket = highest_ticket;

   FileFlush(handle);   
   return;
}

double correctTime( double time_value) 
{
// for some reason all epoch times are 3 hours ahead..... Seriously, how can you get epoch wrong..
return time_value-(3600*3);
}

//+------------------------------------------------------------------+
//| tidy up trades function                                 |
//+------------------------------------------------------------------+

int TidyUpTrades()
{
   //Print("Tidy up trades");
   for(int t = 0;t<=highest_ticket;t++) {
      order_exists[t] = OrderSelect(lowest_ticket + t,SELECT_BY_TICKET);
      if(OrderCloseTime()!=0) { 
         order_exists[t] = false; 
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
   if(IsTesting()) {
      ArrayResize(SymbolPairs,1);
      SymbolPairs[0] = _Symbol;
      suffix = "";
   }

   filename = "Tickets_"+ AccountNumber() + ".log";
   handle=FileOpen(filename,FILE_CSV|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_CSV);

   Print("filename = ",filename, ",  handle = ",handle);

   //EventSetTimer(10);

   reinit();
   
   return;
}

//+------------------------------------------------------------------+
//| expert reinitialization function                                 |
//+------------------------------------------------------------------+

int reinit()
  {
      //----
      for(int f = 0;f<=999997;f++)
         {
            profit_close[f] = false;
            trigger_reached[f] = false;
            order_exists[f] = false;
            current_profit[f] = 0.0;
            tkt_open[f] = 0.0;
            tkt_close[f] = 0.0;
            tkt_high[f] = 0.0;
            tkt_low[f] = 100000.0;
            hedge_tkt[f] = 0;
            f_profit[f] = 0.0;
         }

         
      symbol_profit = 0;
      CloseOutPrice = AccountBalance()*1.03;
      EquityCheck = AccountBalance()*0.95;
      LotPrice = (AccountBalance()/1000);
      Lot = NormalizeDouble(LotPrice/20,2);
      if(Lot<0.01) Lot = 0.01;
      if(Lot>5) Lot = 5;

      MAGICMA = (CloseOutPrice * 100);
      highest_ticket = 0;
      bNewBar();
   
      for(int j=0;j<OrdersTotal();j++)
         { //1
            if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
            if(OrderTicket() < lowest_ticket) lowest_ticket = OrderTicket();
            if(OrderMagicNumber() < MAGICMA && OrderMagicNumber()!=24771442) MAGICMA=OrderMagicNumber();
            if(lowest_ticket == 0) lowest_ticket = OrderTicket();
         }
      Print("MAGICMA - ",MAGICMA," CloseOutPrice - ",CloseOutPrice);
      if(MAGICMA < (CloseOutPrice*100)) CloseOutPrice=MAGICMA/100;
      
      oldOrdersTotal = -1;
      oldHistoryTotal = -1;
      oldMaxTicket = -1;
      trigger_profit = tp;
      drop_profit = dp;
      stop_loss = sl;
      close_up=false;
      Print("CloseOutPrice=",CloseOutPrice,"  LotPrice=",LotPrice,"  Lot=",Lot,"  trigger_profit=",trigger_profit,"  drop_profit=",drop_profit);
      FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+AccountNumber()+" Event=Initialize Equity="+DoubleToStr(AccountEquity(),2)+" CloseUp="+DoubleToStr(CloseOutPrice,2)) ;
      FileFlush(handle);
      //----
   
   return(0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
  {
   FileClose(handle);
   //Print("Files closed");
   EventKillTimer();
   
   return;
  }

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
//---- check for history and trading
   if(IsTradeAllowed()==false) return;
   bNB = bNewBar();
   bM1 = bNewMin();

   if(AccountEquity()>CloseOutPrice && !close_up)
      {
         close_up=true;
         //SendMail("Equity limit reached","All trades closing, current equity="+DoubleToStr(AccountEquity(),2));
         Print("***** Close out price reached, ",AccountEquity()," ********");
         trigger_profit = 0;
         drop_profit = 0;
      }
   if(close_up && SymbolOrders == 0)
      {
         //SendMail("Equity Close Completed","All trades closed, balance="+DoubleToStr(AccountBalance(),2));
         Print("****** Close out completed, balance=",AccountBalance()," ***********");
         //close_email=true;
         close_up=false;
         SendNotification("Close up completed @ "+DoubleToStr(AccountEquity(),2));
         FileWrite(handle,"Time="+DoubleToStr(correctTime(TimeCurrent()),0)+" Account="+AccountNumber()+"Event=Close_Up Equity="+AccountEquity()) ;
         if(!IsTesting()) FileFlush(handle);  
         reinit();
      }

    if(OrdersTotal()==0 && AccountBalance() < EquityCheck) reinit();
      
   CheckForClose();
   
   if (bM1) TidyUpTrades(); 
   
   if (bM1) ExportTrades();

   if (bNB && !close_up  && SymbolOrders < max_trades && AccountEquity() > EquityCheck) CheckForOpen();

   FileFlush(handle);

//----
  }
//+------------------------------------------------------------------+

