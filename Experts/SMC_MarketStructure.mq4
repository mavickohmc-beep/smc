//+------------------------------------------------------------------+
//|                                        SMC_MarketStructure.mq4   |
//|                      Smart Money Concepts - Market Structure EA   |
//|                                   MQL4 / MetaTrader 4 Edition    |
//+------------------------------------------------------------------+
#property copyright "SMC EA"
#property version   "1.00"
#property description "Market structure detection (BOS/ChoCH) for MetaTrader 4"
#property strict

#include "../Include/MarketStructure.mqh"

//--- Input parameters
input int    InpLookback     = 100;            // Lookback candles for analysis
input int    InpSwingStrength = 3;             // Swing strength (bars on each side)
input bool   InpAlertOnChange = true;          // Alert on structure change
input bool   InpShowDashboard = true;          // Show on-chart dashboard
input bool   InpDrawSwings    = true;          // Draw swing point markers
input bool   InpDrawLevels    = true;          // Draw BOS/ChoCH levels
input color  InpBullishColor  = clrDodgerBlue; // Bullish structure color
input color  InpBearishColor  = clrOrangeRed;  // Bearish structure color
input color  InpSwingHighColor = clrLime;      // Swing high marker color
input color  InpSwingLowColor  = clrRed;       // Swing low marker color

//--- Globals
CMarketStructure      marketStructure;
ENUM_MARKET_STRUCTURE lastStructure = MS_UNDEFINED;
datetime              lastBarTime   = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpLookback < 20)
   {
      Print("Lookback must be at least 20 candles");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSwingStrength < 1 || InpSwingStrength > 10)
   {
      Print("Swing strength must be between 1 and 10");
      return INIT_PARAMETERS_INCORRECT;
   }

   marketStructure.Init(_Symbol, _Period, InpLookback, InpSwingStrength);
   marketStructure.Update();
   lastStructure = marketStructure.GetStructure();

   DrawSwingPoints();
   DrawStructureLevels();
   if(InpShowDashboard)
      DrawDashboard();

   Print("SMC Market Structure EA (MT4) v1.0 initialized");
   Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(_Period));
   PrintStructureSummary();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "MS_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on a new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

   marketStructure.Update();

   ENUM_MARKET_STRUCTURE currentStructure = marketStructure.GetStructure();
   if(currentStructure != lastStructure)
   {
      OnStructureChange(lastStructure, currentStructure);
      lastStructure = currentStructure;
   }

   CleanupObjects();
   DrawSwingPoints();
   DrawStructureLevels();
   if(InpShowDashboard)
      DrawDashboard();
}

//+------------------------------------------------------------------+
//| Handle structure change                                          |
//+------------------------------------------------------------------+
void OnStructureChange(ENUM_MARKET_STRUCTURE oldS, ENUM_MARKET_STRUCTURE newS)
{
   StructureEvent lastEvent;
   string eventDesc = "";
   if(marketStructure.GetLastEvent(lastEvent))
      eventDesc = marketStructure.EventToString(lastEvent.type);

   string msg = StringFormat("%s %s: %s -> %s  [%s]",
                             _Symbol, EnumToString(_Period),
                             StructureToString(oldS),
                             StructureToString(newS),
                             eventDesc);
   Print(msg);
   if(InpAlertOnChange)
      Alert(msg);
}

//+------------------------------------------------------------------+
//| Draw swing high/low markers                                      |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   if(!InpDrawSwings) return;

   SwingPoint pt;

   for(int i = 0; i < marketStructure.GetSwingHighCount(); i++)
   {
      if(marketStructure.GetSwingHigh(i, pt))
      {
         string name = "MS_SH_" + IntegerToString(i);
         ObjectCreate(name, OBJ_ARROW, 0, pt.time, pt.price);
         ObjectSet(name, OBJPROP_ARROWCODE, 159);
         ObjectSet(name, OBJPROP_COLOR,     InpSwingHighColor);
         ObjectSet(name, OBJPROP_WIDTH,     2);
      }
   }

   for(int i = 0; i < marketStructure.GetSwingLowCount(); i++)
   {
      if(marketStructure.GetSwingLow(i, pt))
      {
         string name = "MS_SL_" + IntegerToString(i);
         ObjectCreate(name, OBJ_ARROW, 0, pt.time, pt.price);
         ObjectSet(name, OBJPROP_ARROWCODE, 159);
         ObjectSet(name, OBJPROP_COLOR,     InpSwingLowColor);
         ObjectSet(name, OBJPROP_WIDTH,     2);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw BOS/ChoCH horizontal levels                                 |
//+------------------------------------------------------------------+
void DrawStructureLevels()
{
   if(!InpDrawLevels) return;

   StructureEvent ev;

   for(int i = 0; i < marketStructure.GetEventCount(); i++)
   {
      if(marketStructure.GetEvent(i, ev))
      {
         string name  = "MS_LVL_" + IntegerToString(i);
         color  clr   = (ev.type == SE_BOS_BULL || ev.type == SE_CHOCH_BULL)
                        ? InpBullishColor : InpBearishColor;
         int    style = (ev.type == SE_CHOCH_BULL || ev.type == SE_CHOCH_BEAR)
                        ? STYLE_DASH : STYLE_SOLID;
         string label = (ev.type == SE_CHOCH_BULL || ev.type == SE_CHOCH_BEAR)
                        ? "ChoCH" : "BOS";

         // In MQL4, OBJ_TREND uses ObjectCreate with 4 price-time pairs
         ObjectCreate(name, OBJ_TREND, 0,
                      ev.time, ev.level,
                      ev.time + PeriodSeconds(_Period) * 10, ev.level);
         ObjectSet(name, OBJPROP_COLOR,     clr);
         ObjectSet(name, OBJPROP_STYLE,     style);
         ObjectSet(name, OBJPROP_WIDTH,     2);
         ObjectSet(name, OBJPROP_RAY,       false);

         string labelName = "MS_TXT_" + IntegerToString(i);
         ObjectCreate(labelName, OBJ_TEXT, 0, ev.time, ev.level);
         ObjectSetText(labelName, label, 8, "Arial Bold", clr);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw on-chart dashboard using Comment()                          |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   ENUM_MARKET_STRUCTURE ms = marketStructure.GetStructure();

   string structureStr = marketStructure.GetStructureString();
   string eventStr     = "None";
   StructureEvent lastEv;
   if(marketStructure.GetLastEvent(lastEv))
      eventStr = StringFormat("%s @ %.5f",
                              marketStructure.EventToString(lastEv.type),
                              lastEv.level);

   string dash = StringFormat(
      "=== SMC Market Structure (MT4) ===\n"
      "Symbol    : %s  TF: %s\n"
      "Structure : %s\n"
      "Swing H/L : %d / %d\n"
      "Last Event: %s\n"
      "Events    : %d",
      _Symbol, EnumToString(_Period),
      structureStr,
      marketStructure.GetSwingHighCount(), marketStructure.GetSwingLowCount(),
      eventStr,
      marketStructure.GetEventCount()
   );

   Comment(dash);
}

//+------------------------------------------------------------------+
//| Delete redrawable objects before each bar update                 |
//+------------------------------------------------------------------+
void CleanupObjects()
{
   ObjectsDeleteAll(0, "MS_SH_");
   ObjectsDeleteAll(0, "MS_SL_");
   ObjectsDeleteAll(0, "MS_LVL_");
   ObjectsDeleteAll(0, "MS_TXT_");
}

//+------------------------------------------------------------------+
//| Print structure summary to Experts log                           |
//+------------------------------------------------------------------+
void PrintStructureSummary()
{
   Print("=== Market Structure Summary ===");
   Print("Structure  : ", marketStructure.GetStructureString());
   Print("Swing Highs: ", marketStructure.GetSwingHighCount());
   Print("Swing Lows : ", marketStructure.GetSwingLowCount());
   Print("Events     : ", marketStructure.GetEventCount());

   StructureEvent ev;
   for(int i = 0; i < marketStructure.GetEventCount(); i++)
   {
      if(marketStructure.GetEvent(i, ev))
      {
         Print(StringFormat("  #%d  %s  level=%.5f  bar=%d  time=%s",
               i + 1,
               marketStructure.EventToString(ev.type),
               ev.level, ev.barIndex,
               TimeToString(ev.time)));
      }
   }
   Print("================================");
}

//+------------------------------------------------------------------+
//| Helper: enum to string                                           |
//+------------------------------------------------------------------+
string StructureToString(ENUM_MARKET_STRUCTURE ms)
{
   switch(ms)
   {
      case MS_BULLISH:   return "BULLISH";
      case MS_BEARISH:   return "BEARISH";
      case MS_UNDEFINED: return "UNDEFINED";
   }
   return "UNKNOWN";
}
//+------------------------------------------------------------------+
