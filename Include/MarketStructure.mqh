//+------------------------------------------------------------------+
//|                                         MarketStructure.mqh      |
//|                       Market Structure Detection (BOS & ChoCH)   |
//|                                   MQL4 / MetaTrader 4 Edition    |
//+------------------------------------------------------------------+
//| Detects bullish/bearish market structure by scanning swing        |
//| highs and lows, then identifying Break of Structure (BOS) and    |
//| Change of Character (ChoCH) events.                              |
//|                                                                  |
//| Differences from the MQL5 version:                               |
//|  - Constructor uses body initialization (no initializer list)    |
//|  - All method const qualifiers removed (not supported in MQL4)   |
//|  - Default string uses "" instead of NULL                        |
//|  - #property strict required for reliable MQL4 compilation       |
//+------------------------------------------------------------------+
#ifndef MARKET_STRUCTURE_MQH
#define MARKET_STRUCTURE_MQH

#property copyright "SMC EA"
#property version   "1.00"
#property strict

//--- Enumerations
enum ENUM_MARKET_STRUCTURE
{
   MS_BULLISH,     // Bullish market structure
   MS_BEARISH,     // Bearish market structure
   MS_UNDEFINED    // No clear structure yet
};

enum ENUM_STRUCTURE_EVENT
{
   SE_NONE,        // No event
   SE_BOS_BULL,    // Bullish Break of Structure (higher high break)
   SE_BOS_BEAR,    // Bearish Break of Structure (lower low break)
   SE_CHOCH_BULL,  // Bullish Change of Character (break above lower high)
   SE_CHOCH_BEAR   // Bearish Change of Character (break below higher low)
};

//--- Swing point record
struct SwingPoint
{
   double   price;       // Price level of the swing
   int      barIndex;    // Bar index (shift from current bar, 0=current)
   bool     isHigh;      // true = swing high, false = swing low
   datetime time;        // Bar open time of the swing point
};

//--- Structure event record
struct StructureEvent
{
   ENUM_STRUCTURE_EVENT type;      // BOS or ChoCH
   double               level;    // Price level that was broken
   int                  barIndex; // Bar where the break occurred
   datetime             time;     // Time of the event
};

//+------------------------------------------------------------------+
//| CMarketStructure                                                 |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   int                   m_lookback;         // Number of candles to analyze
   int                   m_swingStrength;    // Bars on each side to confirm swing
   string                m_symbol;           // Symbol to analyze
   ENUM_TIMEFRAMES       m_timeframe;        // Timeframe to analyze

   SwingPoint            m_swingHighs[];     // Detected swing highs (oldest first)
   SwingPoint            m_swingLows[];      // Detected swing lows (oldest first)
   StructureEvent        m_events[];         // Detected structure events (oldest first)
   ENUM_MARKET_STRUCTURE m_currentStructure; // Current market structure state

   // Internal helpers
   bool     IsSwingHigh(int barIndex);
   bool     IsSwingLow(int barIndex);
   void     DetectSwingPoints();
   void     AnalyzeStructure();
   void     AddSwingHigh(double price, int barIndex, datetime time);
   void     AddSwingLow(double price, int barIndex, datetime time);
   void     AddEvent(ENUM_STRUCTURE_EVENT type, double level, int barIndex, datetime time);

public:
            CMarketStructure();
           ~CMarketStructure();

   // Setup
   void     Init(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, int swingStrength);

   // Call on every new bar
   void     Update();

   // State getters — no const qualifier in MQL4
   ENUM_MARKET_STRUCTURE GetStructure()      { return m_currentStructure; }
   string                GetStructureString();
   int                   GetSwingHighCount() { return ArraySize(m_swingHighs); }
   int                   GetSwingLowCount()  { return ArraySize(m_swingLows); }
   int                   GetEventCount()     { return ArraySize(m_events); }

   // Access individual records
   bool     GetSwingHigh(int index, SwingPoint &point);
   bool     GetSwingLow(int index, SwingPoint &point);
   bool     GetLastEvent(StructureEvent &event);
   bool     GetEvent(int index, StructureEvent &event);

   // Utility
   string   EventToString(ENUM_STRUCTURE_EVENT type);
};

//+------------------------------------------------------------------+
//| Constructor — body initialization required for MQL4              |
//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure()
{
   m_lookback         = 100;
   m_swingStrength    = 3;
   m_symbol           = "";
   m_timeframe        = PERIOD_CURRENT;
   m_currentStructure = MS_UNDEFINED;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure()
{
}

//+------------------------------------------------------------------+
//| Initialize the detector                                          |
//+------------------------------------------------------------------+
void CMarketStructure::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                             int lookback, int swingStrength)
{
   m_symbol           = symbol;
   m_timeframe        = timeframe;
   m_lookback         = lookback;
   m_swingStrength    = swingStrength;
   m_currentStructure = MS_UNDEFINED;
}

//+------------------------------------------------------------------+
//| Check whether a bar is a swing high                              |
//| A swing high has strictly lower highs on both sides              |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingHigh(int barIndex)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   if(high == 0) return false;

   // Older bars (left side) have higher index
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, barIndex + i) >= high) return false;
   }

   // Newer bars (right side) have lower index
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, barIndex - i) >= high) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check whether a bar is a swing low                               |
//| A swing low has strictly higher lows on both sides               |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingLow(int barIndex)
{
   double low = iLow(m_symbol, m_timeframe, barIndex);
   if(low == 0) return false;

   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iLow(m_symbol, m_timeframe, barIndex + i) <= low) return false;
   }

   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iLow(m_symbol, m_timeframe, barIndex - i) <= low) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Append a swing high record                                       |
//+------------------------------------------------------------------+
void CMarketStructure::AddSwingHigh(double price, int barIndex, datetime time)
{
   int size = ArraySize(m_swingHighs);
   ArrayResize(m_swingHighs, size + 1);
   m_swingHighs[size].price    = price;
   m_swingHighs[size].barIndex = barIndex;
   m_swingHighs[size].isHigh   = true;
   m_swingHighs[size].time     = time;
}

//+------------------------------------------------------------------+
//| Append a swing low record                                        |
//+------------------------------------------------------------------+
void CMarketStructure::AddSwingLow(double price, int barIndex, datetime time)
{
   int size = ArraySize(m_swingLows);
   ArrayResize(m_swingLows, size + 1);
   m_swingLows[size].price    = price;
   m_swingLows[size].barIndex = barIndex;
   m_swingLows[size].isHigh   = false;
   m_swingLows[size].time     = time;
}

//+------------------------------------------------------------------+
//| Append a structure event record                                  |
//+------------------------------------------------------------------+
void CMarketStructure::AddEvent(ENUM_STRUCTURE_EVENT type, double level,
                                 int barIndex, datetime time)
{
   int size = ArraySize(m_events);
   ArrayResize(m_events, size + 1);
   m_events[size].type     = type;
   m_events[size].level    = level;
   m_events[size].barIndex = barIndex;
   m_events[size].time     = time;
}

//+------------------------------------------------------------------+
//| Scan the lookback window and populate swing high/low arrays      |
//| Arrays are filled oldest-first (highest bar index = oldest bar)  |
//+------------------------------------------------------------------+
void CMarketStructure::DetectSwingPoints()
{
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);

   // Valid detection range: skip the outermost swingStrength bars on each end
   int startBar = m_swingStrength;
   int endBar   = m_lookback - m_swingStrength;

   if(endBar <= startBar)
      return;

   // Iterate oldest → newest so arrays stay in chronological order
   for(int i = endBar; i >= startBar; i--)
   {
      datetime barTime = iTime(m_symbol, m_timeframe, i);

      if(IsSwingHigh(i))
         AddSwingHigh(iHigh(m_symbol, m_timeframe, i), i, barTime);

      if(IsSwingLow(i))
         AddSwingLow(iLow(m_symbol, m_timeframe, i), i, barTime);
   }
}

//+------------------------------------------------------------------+
//| Walk through swing points to identify BOS and ChoCH events       |
//|                                                                  |
//| BOS  = trend continuation                                        |
//|   Bullish BOS : new higher-high while already in bullish state   |
//|   Bearish BOS : new lower-low while already in bearish state     |
//| ChoCH = trend reversal                                           |
//|   Bullish ChoCH : breaks above previous high from bearish state  |
//|   Bearish ChoCH : breaks below previous low from bullish state   |
//+------------------------------------------------------------------+
void CMarketStructure::AnalyzeStructure()
{
   ArrayFree(m_events);
   m_currentStructure = MS_UNDEFINED;

   int highCount = ArraySize(m_swingHighs);
   int lowCount  = ArraySize(m_swingLows);

   if(highCount < 2 || lowCount < 2)
      return;

   // Merge both arrays and sort chronologically (oldest = highest barIndex first)
   int totalSwings = highCount + lowCount;
   SwingPoint allSwings[];
   ArrayResize(allSwings, totalSwings);

   int idx = 0;
   for(int i = 0; i < highCount; i++) { allSwings[idx] = m_swingHighs[i]; idx++; }
   for(int i = 0; i < lowCount;  i++) { allSwings[idx] = m_swingLows[i];  idx++; }

   // Bubble sort — descending by barIndex so index 0 = oldest swing
   for(int i = 0; i < totalSwings - 1; i++)
   {
      for(int j = 0; j < totalSwings - i - 1; j++)
      {
         if(allSwings[j].barIndex < allSwings[j + 1].barIndex)
         {
            SwingPoint tmp    = allSwings[j];
            allSwings[j]     = allSwings[j + 1];
            allSwings[j + 1] = tmp;
         }
      }
   }

   double lastSwingHigh = 0;
   double lastSwingLow  = 0;
   bool   hasLastHigh   = false;
   bool   hasLastLow    = false;

   for(int i = 0; i < totalSwings; i++)
   {
      if(allSwings[i].isHigh)
      {
         if(hasLastHigh && hasLastLow)
         {
            if(allSwings[i].price > lastSwingHigh)
            {
               if(m_currentStructure == MS_BULLISH || m_currentStructure == MS_UNDEFINED)
               {
                  if(m_currentStructure == MS_BULLISH)
                     AddEvent(SE_BOS_BULL, lastSwingHigh,
                              allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BULLISH;
               }
               else if(m_currentStructure == MS_BEARISH)
               {
                  AddEvent(SE_CHOCH_BULL, lastSwingHigh,
                           allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BULLISH;
               }
            }
         }
         lastSwingHigh = allSwings[i].price;
         hasLastHigh   = true;
      }
      else
      {
         if(hasLastHigh && hasLastLow)
         {
            if(allSwings[i].price < lastSwingLow)
            {
               if(m_currentStructure == MS_BEARISH || m_currentStructure == MS_UNDEFINED)
               {
                  if(m_currentStructure == MS_BEARISH)
                     AddEvent(SE_BOS_BEAR, lastSwingLow,
                              allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BEARISH;
               }
               else if(m_currentStructure == MS_BULLISH)
               {
                  AddEvent(SE_CHOCH_BEAR, lastSwingLow,
                           allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BEARISH;
               }
            }
         }
         lastSwingLow = allSwings[i].price;
         hasLastLow   = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Run a full detection pass — call this on every new bar           |
//+------------------------------------------------------------------+
void CMarketStructure::Update()
{
   DetectSwingPoints();
   AnalyzeStructure();
}

//+------------------------------------------------------------------+
//| Current structure as a readable string                           |
//+------------------------------------------------------------------+
string CMarketStructure::GetStructureString()
{
   switch(m_currentStructure)
   {
      case MS_BULLISH:   return "BULLISH";
      case MS_BEARISH:   return "BEARISH";
      case MS_UNDEFINED: return "UNDEFINED";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Retrieve a swing high by index (0 = oldest)                      |
//+------------------------------------------------------------------+
bool CMarketStructure::GetSwingHigh(int index, SwingPoint &point)
{
   if(index < 0 || index >= ArraySize(m_swingHighs))
      return false;
   point = m_swingHighs[index];
   return true;
}

//+------------------------------------------------------------------+
//| Retrieve a swing low by index (0 = oldest)                       |
//+------------------------------------------------------------------+
bool CMarketStructure::GetSwingLow(int index, SwingPoint &point)
{
   if(index < 0 || index >= ArraySize(m_swingLows))
      return false;
   point = m_swingLows[index];
   return true;
}

//+------------------------------------------------------------------+
//| Retrieve the most recent structure event                         |
//+------------------------------------------------------------------+
bool CMarketStructure::GetLastEvent(StructureEvent &event)
{
   int size = ArraySize(m_events);
   if(size == 0) return false;
   event = m_events[size - 1];
   return true;
}

//+------------------------------------------------------------------+
//| Retrieve a structure event by index (0 = oldest)                 |
//+------------------------------------------------------------------+
bool CMarketStructure::GetEvent(int index, StructureEvent &event)
{
   if(index < 0 || index >= ArraySize(m_events))
      return false;
   event = m_events[index];
   return true;
}

//+------------------------------------------------------------------+
//| Event type as a readable string                                  |
//+------------------------------------------------------------------+
string CMarketStructure::EventToString(ENUM_STRUCTURE_EVENT type)
{
   switch(type)
   {
      case SE_BOS_BULL:   return "Bullish BOS";
      case SE_BOS_BEAR:   return "Bearish BOS";
      case SE_CHOCH_BULL: return "Bullish ChoCH";
      case SE_CHOCH_BEAR: return "Bearish ChoCH";
      case SE_NONE:       return "None";
   }
   return "Unknown";
}

#endif // MARKET_STRUCTURE_MQH
//+------------------------------------------------------------------+
