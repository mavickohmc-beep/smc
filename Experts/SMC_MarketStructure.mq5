//+------------------------------------------------------------------+
//|                                        SMC_MarketStructure.mq5   |
//|                      Smart Money Concepts - Market Structure EA   |
//+------------------------------------------------------------------+
#property copyright "SMC EA"
#property version   "1.00"
#property description "Identifies market structure (Bullish/Bearish) using BOS and ChoCH"
#property strict

#include "../Include/MarketStructure.mqh"

//--- Input parameters
input int    InpLookback      = 100;           // Lookback candles for analysis
input int    InpSwingStrength  = 3;            // Swing strength (bars on each side)
input bool   InpShowDashboard  = true;         // Show on-chart dashboard
input bool   InpAlertOnChange  = true;         // Alert on structure change
input color  InpBullishColor   = clrDodgerBlue; // Bullish structure color
input color  InpBearishColor   = clrOrangeRed;  // Bearish structure color
input color  InpSwingHighColor = clrLime;       // Swing high marker color
input color  InpSwingLowColor  = clrRed;        // Swing low marker color
input bool   InpDrawSwings     = true;          // Draw swing point markers
input bool   InpDrawLevels     = true;          // Draw BOS/ChoCH levels

//--- Global variables
CMarketStructure marketStructure;
ENUM_MARKET_STRUCTURE lastStructure = MS_UNDEFINED;
datetime lastBarTime = 0;
string   dashboardName = "MS_Dashboard";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate inputs
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

   // Initialize market structure detector
   marketStructure.Init(_Symbol, _Period, InpLookback, InpSwingStrength);

   // Run initial analysis
   marketStructure.Update();
   lastStructure = marketStructure.GetStructure();

   // Draw initial state
   DrawSwingPoints();
   DrawStructureLevels();
   if(InpShowDashboard)
      DrawDashboard();

   Print("SMC Market Structure EA initialized");
   Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(_Period));
   Print("Lookback: ", InpLookback, " | Swing Strength: ", InpSwingStrength);
   PrintStructureSummary();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up chart objects
   ObjectsDeleteAll(0, "MS_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

   // Update market structure
   marketStructure.Update();

   // Check for structure change
   ENUM_MARKET_STRUCTURE currentStructure = marketStructure.GetStructure();

   if(currentStructure != lastStructure)
   {
      OnStructureChange(lastStructure, currentStructure);
      lastStructure = currentStructure;
   }

   // Redraw visual elements
   CleanupObjects();
   DrawSwingPoints();
   DrawStructureLevels();
   if(InpShowDashboard)
      DrawDashboard();
}

//+------------------------------------------------------------------+
//| Handle structure change events                                   |
//+------------------------------------------------------------------+
void OnStructureChange(ENUM_MARKET_STRUCTURE oldStructure, ENUM_MARKET_STRUCTURE newStructure)
{
   StructureEvent lastEvent;
   string eventDesc = "Structure changed";

   if(marketStructure.GetLastEvent(lastEvent))
      eventDesc = marketStructure.EventToString(lastEvent.type);

   string message = StringFormat("%s %s: Structure changed from %s to %s via %s",
                                 _Symbol,
                                 EnumToString(_Period),
                                 StructureToString(oldStructure),
                                 StructureToString(newStructure),
                                 eventDesc);

   Print(message);

   if(InpAlertOnChange)
      Alert(message);
}

//+------------------------------------------------------------------+
//| Draw swing point markers on chart                                |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   if(!InpDrawSwings) return;

   SwingPoint point;

   // Draw swing highs
   for(int i = 0; i < marketStructure.GetSwingHighCount(); i++)
   {
      if(marketStructure.GetSwingHigh(i, point))
      {
         string name = "MS_SH_" + IntegerToString(i);
         ObjectCreate(0, name, OBJ_ARROW, 0, point.time, point.price);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // Down triangle
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingHighColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
                        StringFormat("Swing High: %.5f", point.price));
      }
   }

   // Draw swing lows
   for(int i = 0; i < marketStructure.GetSwingLowCount(); i++)
   {
      if(marketStructure.GetSwingLow(i, point))
      {
         string name = "MS_SL_" + IntegerToString(i);
         ObjectCreate(0, name, OBJ_ARROW, 0, point.time, point.price);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // Up triangle
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingLowColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
                        StringFormat("Swing Low: %.5f", point.price));
      }
   }
}

//+------------------------------------------------------------------+
//| Draw BOS/ChoCH levels on the chart                               |
//+------------------------------------------------------------------+
void DrawStructureLevels()
{
   if(!InpDrawLevels) return;

   StructureEvent event;

   for(int i = 0; i < marketStructure.GetEventCount(); i++)
   {
      if(marketStructure.GetEvent(i, event))
      {
         string name = "MS_LVL_" + IntegerToString(i);
         color lineColor;
         ENUM_LINE_STYLE lineStyle;
         string label;

         switch(event.type)
         {
            case SE_BOS_BULL:
               lineColor = InpBullishColor;
               lineStyle = STYLE_SOLID;
               label = "BOS";
               break;
            case SE_BOS_BEAR:
               lineColor = InpBearishColor;
               lineStyle = STYLE_SOLID;
               label = "BOS";
               break;
            case SE_CHOCH_BULL:
               lineColor = InpBullishColor;
               lineStyle = STYLE_DASH;
               label = "ChoCH";
               break;
            case SE_CHOCH_BEAR:
               lineColor = InpBearishColor;
               lineStyle = STYLE_DASH;
               label = "ChoCH";
               break;
            default:
               continue;
         }

         // Draw horizontal line at the broken level
         ObjectCreate(0, name, OBJ_TREND, 0,
                     event.time, event.level,
                     event.time + PeriodSeconds(_Period) * 10, event.level);
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
                        StringFormat("%s at %.5f", label, event.level));

         // Draw label text
         string labelName = "MS_TXT_" + IntegerToString(i);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, event.time, event.level);
         ObjectSetString(0, labelName, OBJPROP_TEXT, label);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      }
   }
}

//+------------------------------------------------------------------+
//| Draw information dashboard on chart                              |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   int x = 20, y = 30;
   color textColor = clrWhite;
   color bgColor;
   string structureStr = marketStructure.GetStructureString();

   ENUM_MARKET_STRUCTURE ms = marketStructure.GetStructure();
   if(ms == MS_BULLISH)
      bgColor = InpBullishColor;
   else if(ms == MS_BEARISH)
      bgColor = InpBearishColor;
   else
      bgColor = clrGray;

   // Background rectangle
   string bgName = "MS_Dashboard_BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'30,30,30');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   // Title
   CreateLabel("MS_Dashboard_Title", "Market Structure", x, y, 10, clrWhite);
   y += 22;

   // Structure state
   CreateLabel("MS_Dashboard_State", "Structure: " + structureStr, x, y, 11, bgColor);
   y += 20;

   // Swing counts
   string swingInfo = StringFormat("Swing Highs: %d | Lows: %d",
                                   marketStructure.GetSwingHighCount(),
                                   marketStructure.GetSwingLowCount());
   CreateLabel("MS_Dashboard_Swings", swingInfo, x, y, 9, clrSilver);
   y += 18;

   // Last event
   StructureEvent lastEvent;
   string eventStr = "Last Event: None";
   if(marketStructure.GetLastEvent(lastEvent))
      eventStr = "Last: " + marketStructure.EventToString(lastEvent.type) +
                 StringFormat(" @ %.5f", lastEvent.level);
   CreateLabel("MS_Dashboard_Event", eventStr, x, y, 9, clrSilver);
   y += 18;

   // Event count
   CreateLabel("MS_Dashboard_Count",
               StringFormat("Total Events: %d", marketStructure.GetEventCount()),
               x, y, 9, clrSilver);
}

//+------------------------------------------------------------------+
//| Helper: Create a text label on the chart                         |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int fontSize, color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Clean up chart objects before redrawing                           |
//+------------------------------------------------------------------+
void CleanupObjects()
{
   ObjectsDeleteAll(0, "MS_SH_");
   ObjectsDeleteAll(0, "MS_SL_");
   ObjectsDeleteAll(0, "MS_LVL_");
   ObjectsDeleteAll(0, "MS_TXT_");
   ObjectsDeleteAll(0, "MS_Dashboard");
}

//+------------------------------------------------------------------+
//| Print structure summary to Experts log                           |
//+------------------------------------------------------------------+
void PrintStructureSummary()
{
   Print("=== Market Structure Summary ===");
   Print("Current Structure: ", marketStructure.GetStructureString());
   Print("Swing Highs Found: ", marketStructure.GetSwingHighCount());
   Print("Swing Lows Found: ", marketStructure.GetSwingLowCount());
   Print("Structure Events: ", marketStructure.GetEventCount());

   // Print all events
   StructureEvent event;
   for(int i = 0; i < marketStructure.GetEventCount(); i++)
   {
      if(marketStructure.GetEvent(i, event))
      {
         Print(StringFormat("  Event %d: %s at level %.5f | Bar: %d | Time: %s",
               i + 1,
               marketStructure.EventToString(event.type),
               event.level,
               event.barIndex,
               TimeToString(event.time)));
      }
   }
   Print("================================");
}

//+------------------------------------------------------------------+
//| Helper: Convert structure enum to string                         |
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
