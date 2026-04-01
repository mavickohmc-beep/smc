//+------------------------------------------------------------------+
//|                                              MSVisualizer.mqh    |
//|                Market Structure Signal Visualization Module       |
//+------------------------------------------------------------------+
//| Draws shaded background zones between ChoCH signal flips to      |
//| show when bullish/bearish market structure periods began and      |
//| which candles are inside each structure regime.                   |
//+------------------------------------------------------------------+
#ifndef MS_VISUALIZER_MQH
#define MS_VISUALIZER_MQH

#include "MarketStructure.mqh"

//+------------------------------------------------------------------+
//| CMarketStructureViz                                              |
//+------------------------------------------------------------------+
class CMarketStructureViz
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_timeframe;
   color            m_bullishColor;
   color            m_bearishColor;
   bool             m_showLabels;

   void             DrawZone(int index, datetime t1, datetime t2,
                             ENUM_MARKET_STRUCTURE structure, bool isActive);
   void             DrawFlipMarker(int index, datetime t,
                                   ENUM_STRUCTURE_EVENT eventType, bool isActive);
   void             GetZoneBounds(datetime tFrom, datetime tTo,
                                  double &outHigh, double &outLow);
   color            LightenColor(color c, double factor);

public:
                    CMarketStructureViz(void);
                   ~CMarketStructureViz(void);

   void             Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         color bullishColor, color bearishColor,
                         bool showLabels = true);
   void             Draw(CMarketStructure &ms);
   void             Cleanup(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketStructureViz::CMarketStructureViz(void)
   : m_symbol(NULL),
     m_timeframe(PERIOD_CURRENT),
     m_bullishColor(clrDodgerBlue),
     m_bearishColor(clrOrangeRed),
     m_showLabels(true)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketStructureViz::~CMarketStructureViz(void)
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
void CMarketStructureViz::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                                color bullishColor, color bearishColor,
                                bool showLabels)
{
   m_symbol       = symbol;
   m_timeframe    = timeframe;
   m_bullishColor = bullishColor;
   m_bearishColor = bearishColor;
   m_showLabels   = showLabels;
}

//+------------------------------------------------------------------+
//| Remove all MSV_ prefixed chart objects                           |
//+------------------------------------------------------------------+
void CMarketStructureViz::Cleanup(void)
{
   ObjectsDeleteAll(0, "MSV_");
}

//+------------------------------------------------------------------+
//| Blend a color toward white                                       |
//| factor: 0.0 = original color, 1.0 = pure white                  |
//+------------------------------------------------------------------+
color CMarketStructureViz::LightenColor(color c, double factor)
{
   // MQL5 stores colors as 0x00BBGGRR
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);

   r = (int)(r + (255 - r) * factor);
   g = (int)(g + (255 - g) * factor);
   b = (int)(b + (255 - b) * factor);

   if(r > 255) r = 255;
   if(g > 255) g = 255;
   if(b > 255) b = 255;

   return (color)(r | (g << 8) | (b << 16));
}

//+------------------------------------------------------------------+
//| Compute the actual high/low of all candles in the time range     |
//| with a 5% padding so candle wicks sit inside the shaded zone     |
//+------------------------------------------------------------------+
void CMarketStructureViz::GetZoneBounds(datetime tFrom, datetime tTo,
                                         double &outHigh, double &outLow)
{
   // iBarShift: higher bar index = older bar
   int barFrom = iBarShift(m_symbol, m_timeframe, tFrom, false);
   int barTo   = iBarShift(m_symbol, m_timeframe, tTo,   false);

   if(barFrom < 0) barFrom = 0;
   if(barTo   < 0) barTo   = 0;

   int startBar = MathMin(barFrom, barTo);   // newer end (smaller index)
   int endBar   = MathMax(barFrom, barTo);   // older end (larger index)

   outHigh = 0;
   outLow  = DBL_MAX;

   for(int i = startBar; i <= endBar; i++)
   {
      double h = iHigh(m_symbol, m_timeframe, i);
      double l = iLow (m_symbol, m_timeframe, i);
      if(h > 0 && h > outHigh) outHigh = h;
      if(l > 0 && l < outLow)  outLow  = l;
   }

   // Fallback for empty ranges
   if(outLow == DBL_MAX || outHigh <= 0)
   {
      outHigh = iHigh(m_symbol, m_timeframe, 0);
      outLow  = iLow (m_symbol, m_timeframe, 0);
   }

   // 5% padding so zone visually contains all wicks
   double range   = outHigh - outLow;
   double padding = (range > 0) ? range * 0.05 : outHigh * 0.001;
   outHigh += padding;
   outLow  -= padding;
   if(outLow < 0) outLow = 0;
}

//+------------------------------------------------------------------+
//| Draw a filled background rectangle for one structure zone        |
//+------------------------------------------------------------------+
void CMarketStructureViz::DrawZone(int index, datetime t1, datetime t2,
                                    ENUM_MARKET_STRUCTURE structure, bool isActive)
{
   string name = "MSV_Zone_" + IntegerToString(index);

   color baseColor;
   if(structure == MS_BULLISH)      baseColor = m_bullishColor;
   else if(structure == MS_BEARISH) baseColor = m_bearishColor;
   else                              baseColor = clrGray;

   // Active zone: moderately lightened — visible but not overwhelming
   // Historical zones: heavily lightened for subtlety
   color fillColor = isActive ? LightenColor(baseColor, 0.65)
                              : LightenColor(baseColor, 0.82);

   double hi, lo;
   GetZoneBounds(t1, t2, hi, lo);

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      fillColor);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);   // behind candles
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);

   string tooltip = (structure == MS_BULLISH ? "Bullish Zone" : "Bearish Zone");
   if(isActive) tooltip += " (Active)";
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Draw an arrow + label at a ChoCH flip candle                     |
//| isActive: the most recent flip also gets a dotted vertical line   |
//+------------------------------------------------------------------+
void CMarketStructureViz::DrawFlipMarker(int index, datetime t,
                                          ENUM_STRUCTURE_EVENT eventType, bool isActive)
{
   int barShift = iBarShift(m_symbol, m_timeframe, t, false);
   if(barShift < 0) return;

   bool isBullFlip = (eventType == SE_CHOCH_BULL);

   double arrowPrice;
   int    arrowCode;
   int    anchor;
   color  markerColor;
   string labelText;
   int    labelAnchor;

   if(isBullFlip)
   {
      // Bullish ChoCH: up arrow below candle low
      arrowPrice  = iLow(m_symbol, m_timeframe, barShift);
      arrowCode   = 241;               // Up arrow
      anchor      = ANCHOR_TOP;
      markerColor = m_bullishColor;
      labelText   = "ChoCH+";
      labelAnchor = ANCHOR_LEFT_UPPER;
   }
   else
   {
      // Bearish ChoCH: down arrow above candle high
      arrowPrice  = iHigh(m_symbol, m_timeframe, barShift);
      arrowCode   = 242;               // Down arrow
      anchor      = ANCHOR_BOTTOM;
      markerColor = m_bearishColor;
      labelText   = "ChoCH-";
      labelAnchor = ANCHOR_LEFT_LOWER;
   }

   // Arrow
   string arrowName = "MSV_Arrow_" + IntegerToString(index);
   ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, arrowPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE,  arrowCode);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR,      markerColor);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH,      isActive ? 3 : 2);
   ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR,     anchor);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN,     true);
   ObjectSetString(0,  arrowName, OBJPROP_TOOLTIP,
                   (isBullFlip ? "Bullish ChoCH" : "Bearish ChoCH") +
                   string(" @ ") + TimeToString(t));

   // Text label
   if(m_showLabels)
   {
      string labelName = "MSV_Label_" + IntegerToString(index);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, t, arrowPrice);
      ObjectSetString(0,  labelName, OBJPROP_TEXT,      labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR,     markerColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE,  8);
      ObjectSetString(0,  labelName, OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR,    labelAnchor);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN,    true);
   }

   // Dotted vertical line marks the most recent flip
   if(isActive)
   {
      string vlineName = "MSV_VLine";
      ObjectCreate(0, vlineName, OBJ_VLINE, 0, t, 0);
      ObjectSetInteger(0, vlineName, OBJPROP_COLOR,     markerColor);
      ObjectSetInteger(0, vlineName, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, vlineName, OBJPROP_WIDTH,     1);
      ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, vlineName, OBJPROP_HIDDEN,    true);
      ObjectSetString(0,  vlineName, OBJPROP_TOOLTIP,
                      "Last structure flip: " + TimeToString(t));
   }
}

//+------------------------------------------------------------------+
//| Rebuild and draw the full zone timeline                          |
//|                                                                  |
//| Zone logic:                                                       |
//|  - Only ChoCH events create new zones (BOS = continuation)       |
//|  - Zone 0 covers oldest-swing-point to first ChoCH               |
//|  - Each ChoCH starts a new zone that runs to the next ChoCH      |
//|  - The final zone runs from the last ChoCH to the current bar    |
//|  - Initial zone color = opposite of first ChoCH direction         |
//+------------------------------------------------------------------+
void CMarketStructureViz::Draw(CMarketStructure &ms)
{
   Cleanup();

   // Determine the analysis start using the earliest detected swing point
   datetime zoneStart = 0;
   SwingPoint pt;
   if(ms.GetSwingHigh(0, pt) && pt.time > 0)
      zoneStart = pt.time;
   if(ms.GetSwingLow(0, pt) && pt.time > 0)
   {
      if(zoneStart == 0 || pt.time < zoneStart)
         zoneStart = pt.time;
   }

   if(zoneStart == 0)
      return; // No swing data yet

   datetime currentTime = iTime(m_symbol, m_timeframe, 0);

   // Collect ChoCH events in chronological order (events array is oldest-first)
   int totalEvents = ms.GetEventCount();
   StructureEvent chochEvents[];
   int chochCount = 0;

   StructureEvent ev;
   for(int i = 0; i < totalEvents; i++)
   {
      if(ms.GetEvent(i, ev))
      {
         if(ev.type == SE_CHOCH_BULL || ev.type == SE_CHOCH_BEAR)
         {
            ArrayResize(chochEvents, chochCount + 1);
            chochEvents[chochCount] = ev;
            chochCount++;
         }
      }
   }

   // --- No ChoCH events: single zone from oldest swing to current bar ---
   if(chochCount == 0)
   {
      DrawZone(0, zoneStart, currentTime, ms.GetStructure(), true);
      return;
   }

   // --- Initial zone before the first ChoCH ---
   // Color = opposite of what the first ChoCH triggered
   ENUM_MARKET_STRUCTURE initStructure = (chochEvents[0].type == SE_CHOCH_BULL)
                                        ? MS_BEARISH : MS_BULLISH;
   DrawZone(0, zoneStart, chochEvents[0].time, initStructure, false);

   // --- Zone for each ChoCH, plus its flip marker ---
   for(int i = 0; i < chochCount; i++)
   {
      bool     isLast        = (i == chochCount - 1);
      datetime zoneEnd       = isLast ? currentTime : chochEvents[i + 1].time;
      ENUM_MARKET_STRUCTURE zoneStructure = (chochEvents[i].type == SE_CHOCH_BULL)
                                           ? MS_BULLISH : MS_BEARISH;

      DrawZone(i + 1, chochEvents[i].time, zoneEnd, zoneStructure, isLast);
      DrawFlipMarker(i, chochEvents[i].time, chochEvents[i].type, isLast);
   }
}

#endif // MS_VISUALIZER_MQH
//+------------------------------------------------------------------+
