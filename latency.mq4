//+------------------------------------------------------------------+
//|                                                    LatencyEA.mq4 |
//|                                                       MellyForex |
//|                                        http://www.mellyforex.com |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2012, MellyForex"
#property link      "http://www.mellyforex.com"

//--- input parameters
extern int     testOrderFrequency = 5;

datetime       lastTestOrderSent = 0;
int            testOrderFrequencySeconds;
int            magic = 4156434123;
int            minExecutionTime = 99999999;
int            maxExecutionTime = 0;
int            avExecutionTime = 0;
int            totalExecutionTime = 0;
int            totalTestTrades = 0;


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   testOrderFrequencySeconds = testOrderFrequency * 60;
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   Comment("");   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   int openTicket = openTestOrderTicket();
   if(openTicket > 0)  closeTestOrder(openTicket);
   string text = "The Latency EA is sending test orders at "+testOrderFrequency+" minute intervals\n";
   if(minExecutionTime < 99999999)  {
      text = text + "Maximum Latency = "+maxExecutionTime+" milliseconds\n";
      text = text + "Minimum Latency = "+minExecutionTime+" milliseconds\n";
      text = text + "Average Latency = "+avExecutionTime+" milliseconds";
      }
   if(TimeCurrent() - lastTestOrderSent < testOrderFrequencySeconds)  {
      Comment(text);
      return(0);
      }
   if(openTicket == 0)  openTestOrder();
//----
   return(0);
  }
//+------------------------------------------------------------------+

void openTestOrder()  {
   int ticket=0; 
   int err=0; 
   int c = 0;
   int attempts = 20;
   double testOrderPrice = 1 / MathPow(10, Digits);
   double size = MarketInfo(Symbol(),MODE_MINLOT);

   while(ticket <= 0 && c < attempts){ 
      int xyz = 1;  //if the waiting time is exceeded (-1 is returned), let's recheck every 15 secs
      while(xyz == 1){ 
            if( !IsTradeAllowed() ) {
            Sleep(15000);
            c++;
            Print("A Trade Context delay prevented the Latency EA from opening a test order at attempt #"+c);
            continue;
            }
         if( IsTradeAllowed() ) break;
         if(c >= attempts)  {Alert("Trade attempts on "+Symbol()+" maxed at "+attempts); return;}
        }
        
   int startOrderTimestamp = GetTickCount();
   int elapsed = 0;
   ticket = OrderSend(Symbol(), OP_BUYLIMIT, size, NormalizeDouble(testOrderPrice, Digits), 0, 0, 0, "Latency EA", magic, 0, CLR_NONE);
   elapsed = GetTickCount() - startOrderTimestamp; 

   if (ticket > 0) {
      Print("The Latency EA took "+elapsed+" milliseconds to open test LIMIT BUY ticket #"+ticket);
      if(elapsed < minExecutionTime)  minExecutionTime = elapsed;
      if(elapsed > maxExecutionTime)  maxExecutionTime = elapsed;
      totalExecutionTime += elapsed;
      totalTestTrades ++;
      avExecutionTime = totalExecutionTime / totalTestTrades;
      return;
      }
               
   if(ticket < 0)  {
      Print("A LIMIT BUY order send failed with error #", GetLastError());
      return;
      }
   }
}

void closeTestOrder(int ticket)  {

   int startOrderTimestamp = GetTickCount();
   int elapsed = 0;
   bool success = OrderDelete(ticket, CLR_NONE);
   elapsed = GetTickCount() - startOrderTimestamp; 
   
   if(success)  {
      Print("The Latency EA took "+elapsed+" milliseconds to close test LIMIT BUY ticket #"+ticket);
      if(elapsed < minExecutionTime)  minExecutionTime = elapsed;
      if(elapsed > maxExecutionTime)  maxExecutionTime = elapsed;
      totalExecutionTime += elapsed;
      totalTestTrades ++;
      avExecutionTime = totalExecutionTime / totalTestTrades;
      lastTestOrderSent = TimeCurrent();
      return;
      }
      
   return;
}

int openTestOrderTicket()  {
   int Total = OrdersTotal();
   int ret = 0;
   for (int i = 0; i < Total; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic )  {
         ret = OrderTicket();
      }
   }
   return(ret);

}
