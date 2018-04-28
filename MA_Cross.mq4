//+------------------------------------------------------------------+
//|                                                     MA_Cross.mq4 |
//|                                     Copyright 2018, Codatrek.com |
//|                                         https://www.codatrek.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Codatrek.com"
#property link      "https://www.codatrek.com"
#property version   "1.00"
#property strict

double   MA50last,MA50now,MA200last,MA200now;
extern double    tp = 250;
extern double    sl = 500;

double   Lot=0.1;
double   ask_price,bid_price,points;
int      MAGICMA;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   OnNewBar();

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
//|                                                                  |
//+------------------------------------------------------------------+
bool OnNewBar()
  {

   ask_price=MarketInfo(_Symbol,MODE_ASK);
   bid_price=MarketInfo(_Symbol,MODE_BID);
   points=MarketInfo(_Symbol,MODE_POINT);

   MA200now=iMA(_Symbol,NULL,200,0,MODE_SMA,PRICE_CLOSE,0);
   MA200last=iMA(_Symbol,NULL,200,1,MODE_SMA,PRICE_CLOSE,0);

   MA50now=iMA(_Symbol,NULL,50,0,MODE_SMA,PRICE_CLOSE,0);
   MA50last=iMA(_Symbol,NULL,50,1,MODE_SMA,PRICE_CLOSE,0);

   if(MA50last>MA200last && MA200now>MA50now)
     {
      //cross up = SELL
      double take=bid_price -(tp*points);
      double stop=ask_price + (sl*points);
      int res=OrderSend(_Symbol,OP_SELL,Lot,bid_price,3,NULL,take,NULL,MAGICMA,0,Red);

     }

   if(MA50last<MA200last && MA200now<MA50now)
     {
      //cross down = BUY
      double take=ask_price + (tp*points);
      double stop=bid_price -(sl*points);
      int res=OrderSend(_Symbol,OP_BUY,Lot,ask_price,3,NULL,take,NULL,MAGICMA,0,Green);

     }

   return 0;
  }
//+------------------------------------------------------------------+
