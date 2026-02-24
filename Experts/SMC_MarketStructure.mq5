//+------------------------------------------------------------------+
//|                                        SMC_MarketStructure.mq5   |
//|                      Smart Money Concepts - Market Structure EA   |
//+------------------------------------------------------------------+
#property copyright "SMC EA"
#property version   "2.00"
#property description "Market structure (BOS/ChoCH) and Triangle pattern detection with breakout validation"
#property strict

#include "../Include/MarketStructure.mqh"
#include "../Include/TrianglePatterns.mqh"

//--- Input parameters: Market Structure
input group  "=== Market Structure ==="
input int    InpLookback      = 100;           // Lookback candles for analysis
input int    InpSwingStrength  = 3;            // Swing strength (bars on each side)
input bool   InpAlertOnChange  = true;         // Alert on structure change

//--- Input parameters: Triangle Patterns
input group  "=== Triangle Patterns ==="
input int    InpTriMinSwings     = 3;          // Min swing points per side for triangle
input double InpTriFlatThreshold = 0.002;      // Flat slope threshold (% of price/bar)
input double InpTriBreakoutPct   = 0.15;       // Breakout margin (% beyond trendline)
input bool   InpTriDrawLines     = true;       // Draw triangle trendlines on chart
input bool   InpAlertOnBreakout  = true;       // Alert on triangle breakout

//--- Input parameters: Visuals
input group  "=== Visual Settings ==="
input bool   InpShowDashboard  = true;         // Show on-chart dashboard
input color  InpBullishColor   = clrDodgerBlue; // Bullish structure color
input color  InpBearishColor   = clrOrangeRed;  // Bearish structure color
input color  InpSwingHighColor = clrLime;       // Swing high marker color
input color  InpSwingLowColor  = clrRed;        // Swing low marker color
input bool   InpDrawSwings     = true;          // Draw swing point markers
input bool   InpDrawLevels     = true;          // Draw BOS/ChoCH levels
input color  InpTriUpperColor  = clrGold;       // Triangle upper trendline color
input color  InpTriLowerColor  = clrMagenta;    // Triangle lower trendline color

//--- Global variables
CMarketStructure marketStructure;
CTrianglePattern trianglePattern;
ENUM_MARKET_STRUCTURE lastStructure = MS_UNDEFINED;
ENUM_PRICE_POSITION   lastTriPosition = PP_NO_TRIANGLE;
datetime lastBarTime = 0;

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

   // Initialize triangle pattern detector
   trianglePattern.Init(_Symbol, _Period, InpTriMinSwings, InpTriFlatThreshold,
                        InpTriBreakoutPct);

   // Run initial analysis
   marketStructure.Update();
   trianglePattern.Analyze(marketStructure);
   lastStructure   = marketStructure.GetStructure();
   lastTriPosition = trianglePattern.GetPricePosition();

   // Draw initial state
   DrawSwingPoints();
   DrawStructureLevels();
   DrawTriangleTrendlines();
   if(InpShowDashboard)
      DrawDashboard();

   Print("SMC Market Structure EA v2.0 initialized");
   Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(_Period));
   Print("Lookback: ", InpLookback, " | Swing Strength: ", InpSwingStrength);
   PrintStructureSummary();
   PrintTriangleSummary();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "MS_");
   ObjectsDeleteAll(0, "TRI_");
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

   // Update triangle pattern analysis
   trianglePattern.Analyze(marketStructure);

   // Check for structure change
   ENUM_MARKET_STRUCTURE currentStructure = marketStructure.GetStructure();
   if(currentStructure != lastStructure)
   {
      OnStructureChange(lastStructure, currentStructure);
      lastStructure = currentStructure;
   }

   // Check for triangle breakout
   ENUM_PRICE_POSITION currentTriPosition = trianglePattern.GetPricePosition();
   if(currentTriPosition != lastTriPosition)
   {
      OnTriangleEvent(lastTriPosition, currentTriPosition);
      lastTriPosition = currentTriPosition;
   }

   // Redraw visual elements
   CleanupObjects();
   DrawSwingPoints();
   DrawStructureLevels();
   DrawTriangleTrendlines();
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
                                 _Symbol, EnumToString(_Period),
                                 StructureToString(oldStructure),
                                 StructureToString(newStructure),
                                 eventDesc);
   Print(message);

   if(InpAlertOnChange)
      Alert(message);
}

//+------------------------------------------------------------------+
//| Handle triangle position change events                           |
//+------------------------------------------------------------------+
void OnTriangleEvent(ENUM_PRICE_POSITION oldPos, ENUM_PRICE_POSITION newPos)
{
   TriangleResult result = trianglePattern.GetResult();

   string message = StringFormat("%s %s: Triangle #%d %s | %s -> %s",
                                 _Symbol, EnumToString(_Period),
                                 result.candidateIndex,
                                 trianglePattern.PatternToString(result.pattern),
                                 trianglePattern.PositionToString(oldPos),
                                 trianglePattern.PositionToString(newPos));

   if(newPos == PP_BREAKOUT_ABOVE || newPos == PP_BREAKOUT_BELOW)
   {
      message += StringFormat(" (%.2f%%) | %s",
                              result.breakoutPercent,
                              trianglePattern.ValidationToString(result.validation));
   }
   else if(newPos == PP_INSIDE)
   {
      message += " | Strength: " + trianglePattern.StrengthToString(result.strength);
   }

   Print(message);

   if(InpAlertOnBreakout && (newPos == PP_BREAKOUT_ABOVE || newPos == PP_BREAKOUT_BELOW))
      Alert(message);
}

//+------------------------------------------------------------------+
//| Draw swing point markers on chart                                |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   if(!InpDrawSwings) return;

   SwingPoint point;

   for(int i = 0; i < marketStructure.GetSwingHighCount(); i++)
   {
      if(marketStructure.GetSwingHigh(i, point))
      {
         string name = "MS_SH_" + IntegerToString(i);
         ObjectCreate(0, name, OBJ_ARROW, 0, point.time, point.price);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingHighColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
                        StringFormat("Swing High: %.5f", point.price));
      }
   }

   for(int i = 0; i < marketStructure.GetSwingLowCount(); i++)
   {
      if(marketStructure.GetSwingLow(i, point))
      {
         string name = "MS_SL_" + IntegerToString(i);
         ObjectCreate(0, name, OBJ_ARROW, 0, point.time, point.price);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
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
            case SE_BOS_BULL:   lineColor = InpBullishColor; lineStyle = STYLE_SOLID; label = "BOS";   break;
            case SE_BOS_BEAR:   lineColor = InpBearishColor; lineStyle = STYLE_SOLID; label = "BOS";   break;
            case SE_CHOCH_BULL: lineColor = InpBullishColor; lineStyle = STYLE_DASH;  label = "ChoCH"; break;
            case SE_CHOCH_BEAR: lineColor = InpBearishColor; lineStyle = STYLE_DASH;  label = "ChoCH"; break;
            default: continue;
         }

         ObjectCreate(0, name, OBJ_TREND, 0,
                     event.time, event.level,
                     event.time + PeriodSeconds(_Period) * 10, event.level);
         ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetString(0, name, OBJPROP_TOOLTIP,
                        StringFormat("%s at %.5f", label, event.level));

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
//| Draw the selected triangle's trendlines on chart                 |
//| Uses regression-projected start/end points for accurate lines    |
//+------------------------------------------------------------------+
void DrawTriangleTrendlines()
{
   if(!InpTriDrawLines) return;

   TriangleResult result = trianglePattern.GetResult();
   if(result.pattern == TP_NONE) return;

   datetime currentTime = iTime(_Symbol, _Period, 0);

   // Upper trendline: from regression start to current bar projection
   string upperName = "TRI_Upper";
   ObjectCreate(0, upperName, OBJ_TREND, 0,
               result.trendStartTime, result.upperAtStart,
               currentTime, result.upperLevel);
   ObjectSetInteger(0, upperName, OBJPROP_COLOR, InpTriUpperColor);
   ObjectSetInteger(0, upperName, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, upperName, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(0, upperName, OBJPROP_TOOLTIP,
                  StringFormat("Upper: %.5f (slope:%.6f R²:%.2f)",
                               result.upperLevel, result.highSlope, result.highR2));

   // Lower trendline
   string lowerName = "TRI_Lower";
   ObjectCreate(0, lowerName, OBJ_TREND, 0,
               result.trendStartTime, result.lowerAtStart,
               currentTime, result.lowerLevel);
   ObjectSetInteger(0, lowerName, OBJPROP_COLOR, InpTriLowerColor);
   ObjectSetInteger(0, lowerName, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lowerName, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(0, lowerName, OBJPROP_TOOLTIP,
                  StringFormat("Lower: %.5f (slope:%.6f R²:%.2f)",
                               result.lowerLevel, result.lowSlope, result.lowR2));

   // Pattern label at midpoint
   string patLabel = "TRI_PatternLabel";
   double midPrice = (result.upperLevel + result.lowerLevel) / 2.0;
   ObjectCreate(0, patLabel, OBJ_TEXT, 0, currentTime, midPrice);
   ObjectSetString(0, patLabel, OBJPROP_TEXT,
                  StringFormat("Tri#%d %s", result.candidateIndex,
                               trianglePattern.PatternToString(result.pattern)));
   ObjectSetInteger(0, patLabel, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, patLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, patLabel, OBJPROP_FONT, "Arial Bold");

   // Breakout arrow with validation color
   if(result.pricePosition == PP_BREAKOUT_ABOVE)
   {
      string arrowName = "TRI_BreakoutArrow";
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, currentTime, result.upperLevel);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 241);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR,
                      (result.validation == BV_VALIDATED) ? clrLime : clrOrange);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);

      // Validation label
      string valLabel = "TRI_ValidationLabel";
      ObjectCreate(0, valLabel, OBJ_TEXT, 0, currentTime, result.upperLevel);
      ObjectSetString(0, valLabel, OBJPROP_TEXT,
                     trianglePattern.ValidationToString(result.validation));
      ObjectSetInteger(0, valLabel, OBJPROP_COLOR,
                      (result.validation == BV_VALIDATED) ? clrLime : clrOrange);
      ObjectSetInteger(0, valLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, valLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, valLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }
   else if(result.pricePosition == PP_BREAKOUT_BELOW)
   {
      string arrowName = "TRI_BreakoutArrow";
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, currentTime, result.lowerLevel);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 242);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR,
                      (result.validation == BV_VALIDATED) ? clrRed : clrOrange);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);

      string valLabel = "TRI_ValidationLabel";
      ObjectCreate(0, valLabel, OBJ_TEXT, 0, currentTime, result.lowerLevel);
      ObjectSetString(0, valLabel, OBJPROP_TEXT,
                     trianglePattern.ValidationToString(result.validation));
      ObjectSetInteger(0, valLabel, OBJPROP_COLOR,
                      (result.validation == BV_VALIDATED) ? clrRed : clrOrange);
      ObjectSetInteger(0, valLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, valLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, valLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
}

//+------------------------------------------------------------------+
//| Draw information dashboard on chart                              |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   int x = 20, y = 30;
   color bgColor;

   ENUM_MARKET_STRUCTURE ms = marketStructure.GetStructure();
   if(ms == MS_BULLISH)       bgColor = InpBullishColor;
   else if(ms == MS_BEARISH)  bgColor = InpBearishColor;
   else                        bgColor = clrGray;

   TriangleResult triResult = trianglePattern.GetResult();
   bool hasTriangle = (triResult.pattern != TP_NONE);
   int dashHeight = hasTriangle ? 290 : 175;

   // Background
   string bgName = "MS_Dashboard_BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 290);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, dashHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'30,30,30');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   // === Market Structure Section ===
   CreateLabel("MS_Dashboard_Title", "Market Structure", x, y, 10, clrWhite);
   y += 22;

   CreateLabel("MS_Dashboard_State", "Structure: " + marketStructure.GetStructureString(),
               x, y, 11, bgColor);
   y += 20;

   CreateLabel("MS_Dashboard_Swings",
               StringFormat("Swing Highs: %d | Lows: %d",
                            marketStructure.GetSwingHighCount(),
                            marketStructure.GetSwingLowCount()),
               x, y, 9, clrSilver);
   y += 18;

   StructureEvent lastEvent;
   string eventStr = "Last Event: None";
   if(marketStructure.GetLastEvent(lastEvent))
      eventStr = "Last: " + marketStructure.EventToString(lastEvent.type) +
                 StringFormat(" @ %.5f", lastEvent.level);
   CreateLabel("MS_Dashboard_Event", eventStr, x, y, 9, clrSilver);
   y += 18;

   CreateLabel("MS_Dashboard_Count",
               StringFormat("Total Events: %d", marketStructure.GetEventCount()),
               x, y, 9, clrSilver);
   y += 22;

   // === Triangle Pattern Section ===
   CreateLabel("MS_Dashboard_TriTitle", "--- Triangle Pattern ---", x, y, 10, clrWhite);
   y += 20;

   // Candidates overview line
   string candSummary = trianglePattern.GetCandidatesSummary();
   CreateLabel("MS_Dashboard_TriCands", candSummary, x, y, 8, clrDarkGray);
   y += 16;

   if(hasTriangle)
   {
      // Selected candidate and pattern
      string selStr = StringFormat("Selected: #%d %s",
                                   triResult.candidateIndex,
                                   trianglePattern.PatternToString(triResult.pattern));
      CreateLabel("MS_Dashboard_TriSel", selStr, x, y, 10, clrYellow);
      y += 18;

      // R-squared values
      CreateLabel("MS_Dashboard_TriR2",
                  StringFormat("R²: High=%.3f Low=%.3f", triResult.highR2, triResult.lowR2),
                  x, y, 9, clrSilver);
      y += 16;

      // Price position
      string posStr = trianglePattern.PositionToString(triResult.pricePosition);
      color posColor = clrSilver;
      if(triResult.pricePosition == PP_BREAKOUT_ABOVE) posColor = clrLime;
      else if(triResult.pricePosition == PP_BREAKOUT_BELOW) posColor = clrRed;

      CreateLabel("MS_Dashboard_TriPos", "Position: " + posStr, x, y, 9, posColor);
      y += 16;

      // Strength or breakout info
      if(triResult.pricePosition == PP_INSIDE)
      {
         string strStr = "Strength: " + trianglePattern.StrengthToString(triResult.strength);
         color strColor = clrSilver;
         if(triResult.strength == TS_STRONG_BULLISH || triResult.strength == TS_BULLISH)
            strColor = InpBullishColor;
         else if(triResult.strength == TS_STRONG_BEARISH || triResult.strength == TS_BEARISH)
            strColor = InpBearishColor;

         CreateLabel("MS_Dashboard_TriStr", strStr, x, y, 9, strColor);
         y += 16;
      }
      else if(triResult.pricePosition == PP_BREAKOUT_ABOVE || triResult.pricePosition == PP_BREAKOUT_BELOW)
      {
         // Breakout percentage
         CreateLabel("MS_Dashboard_TriStr",
                     StringFormat("Breakout: %.2f%% beyond", triResult.breakoutPercent),
                     x, y, 9, posColor);
         y += 16;

         // Validation status
         string valStr = "Validation: " + trianglePattern.ValidationToString(triResult.validation);
         color valColor = clrSilver;
         if(triResult.validation == BV_VALIDATED) valColor = clrLime;
         else if(triResult.validation == BV_INVALIDATED) valColor = clrOrange;

         CreateLabel("MS_Dashboard_TriVal", valStr, x, y, 9, valColor);
         y += 16;
      }

      // Trendline levels
      CreateLabel("MS_Dashboard_TriUpper",
                  StringFormat("Upper: %.5f", triResult.upperLevel), x, y, 9, InpTriUpperColor);
      y += 14;
      CreateLabel("MS_Dashboard_TriLower",
                  StringFormat("Lower: %.5f", triResult.lowerLevel), x, y, 9, InpTriLowerColor);
      y += 14;

      // Apex distance
      if(triResult.apexBarDistance < 9999)
         CreateLabel("MS_Dashboard_TriApex",
                     StringFormat("Apex in ~%.0f bars", triResult.apexBarDistance),
                     x, y, 9, clrSilver);
      else
         CreateLabel("MS_Dashboard_TriApex", "Apex: distant", x, y, 9, clrSilver);
   }
   else
   {
      CreateLabel("MS_Dashboard_TriSel", "No valid triangle", x, y, 9, clrGray);
   }
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
   ObjectsDeleteAll(0, "TRI_");
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
//| Print triangle pattern summary to Experts log                    |
//+------------------------------------------------------------------+
void PrintTriangleSummary()
{
   Print("=== Triangle Pattern Summary ===");

   // Print all 5 candidates
   TriangleCandidate cand;
   for(int i = 0; i < TRIANGLE_CANDIDATES; i++)
   {
      if(trianglePattern.GetCandidate(i, cand))
      {
         if(cand.isValid)
         {
            Print(StringFormat("  Tri#%d: %s | R²:%.3f | Score:%.3f | Upper:%.5f Lower:%.5f%s",
                  i + 1,
                  trianglePattern.PatternToString(cand.pattern),
                  cand.combinedR2,
                  cand.score,
                  cand.upperAtCurrent,
                  cand.lowerAtCurrent,
                  (i == trianglePattern.GetBestCandidateIndex()) ? " << SELECTED" : ""));
         }
         else
         {
            Print(StringFormat("  Tri#%d: (no valid pattern)", i + 1));
         }
      }
   }

   // Print selected result
   TriangleResult result = trianglePattern.GetResult();
   if(result.pattern != TP_NONE)
   {
      Print("---");
      Print("Best: ", trianglePattern.GetSummary());
      Print("Position: ", trianglePattern.PositionToString(result.pricePosition));

      if(result.pricePosition == PP_INSIDE)
         Print("Strength: ", trianglePattern.StrengthToString(result.strength));
      else if(result.pricePosition == PP_BREAKOUT_ABOVE || result.pricePosition == PP_BREAKOUT_BELOW)
      {
         Print(StringFormat("Breakout: %.2f%% | Validation: %s",
               result.breakoutPercent,
               trianglePattern.ValidationToString(result.validation)));
      }
   }
   else
   {
      Print("No valid triangle pattern detected");
   }

   Print("Candidates: ", trianglePattern.GetCandidatesSummary());
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
