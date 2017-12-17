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

datetime LastTick[20]; // same number as symbol pairs or greater
string   SymbolPairs[]=
  {
   "EURUSD","EURGBP","GBPUSD",
   "AUDUSD","EURJPY","AUDJPY",
   "EURAUD","USDCAD","USDJPY",
   "GBPCAD","AUDCAD","USDCHF",
   "GBPAUD","XAUUSD"
  };
int      handle;
int      RSIperiod=14;
int      AppliedPrice=4;

datetime TickTime;
string   Check_Symbol,suffix="";
string fileName="SPLUNK_MT_Log.csv";
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer

   suffix=StringSubstr(Symbol(),6,4);

   Print("Start Expert Advisor");
   if(IsTesting()) fileName=Symbol()+"_"+fileName;
   Print("Writing to ",fileName);
   handle=FileOpen(fileName,FILE_CSV|FILE_SHARE_READ|FILE_WRITE);
   if(handle==0) Print("Error opening log file");
   FileWrite(handle,"Time,Event,Symbol,Value");
//   FileClose(handle);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   FileFlush(handle);
   FileClose(handle);
   Print("Close Expert Advisor");

  }
//+------------------------------------------------------------------+
//|   sort out the incorrect epoch                                   |
//+------------------------------------------------------------------+
double correctTime(double time_value)
  {
// for some reason all epoch times are 2 hours ahead..... Seriously, how can you get epoch wrong..
//   return time_value-(3600*2);
// European summer time, 3 hours ahead
   return time_value-(3600*3);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
//   handle=FileOpen(fileName,FILE_CSV|FILE_READ|FILE_WRITE);
//   if(handle==0) Print("Error opening log file");
//   FileSeek(handle,0,SEEK_END);
   for(int a=0; a<ArraySize(SymbolPairs); a++)
     {
      Check_Symbol=SymbolPairs[a]+suffix;
      MqlTick last_tick;
      if(SymbolInfoTick(Check_Symbol,last_tick))
        {
         double new_time=correctTime(last_tick.time_msc/1000);
         double RSInow=iRSI(Check_Symbol,NULL,RSIperiod,AppliedPrice,0);
         double iStochValue=iStochastic(Check_Symbol,NULL,5,3,3,MODE_SMMA,1,MODE_MAIN,1);
         double iCciValue=iCCI(Check_Symbol,NULL,RSIperiod,AppliedPrice,0);
         double iVol=iVolume(Check_Symbol,NULL,0);

         if(new_time>LastTick[a])
           {
            FileWrite(handle,new_time+",BID,"+Check_Symbol+"i,"+DoubleToString(last_tick.bid,5));
            FileWrite(handle,new_time+",ASK,"+Check_Symbol+"i,"+DoubleToString(last_tick.ask,5));
            FileWrite(handle,new_time+",RSI,"+Check_Symbol+"i,"+DoubleToString(RSInow,5));
            FileWrite(handle,new_time+",STOCH,"+Check_Symbol+"i,"+DoubleToString(iStochValue,5));
            FileWrite(handle,new_time+",CCI,"+Check_Symbol+"i,"+DoubleToString(iCciValue,5));
            FileWrite(handle,new_time+",VOL,"+Check_Symbol+"i,"+DoubleToString(iVol,2));
            if(IsTesting())
              {
               // you wait, time passes
                 } else {
               FileFlush(handle);
              };
            LastTick[a]=new_time;
           }
        }
     }
//   FileClose(handle);
  }

//+------------------------------------------------------------------+
