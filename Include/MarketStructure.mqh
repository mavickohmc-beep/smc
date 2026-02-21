//+------------------------------------------------------------------+
//|                                           MarketStructure.mqh    |
//|                        Market Structure Detection (BOS & ChoCH)  |
//+------------------------------------------------------------------+
#property copyright "SMC EA"
#property version   "1.00"

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

//--- Swing point structure
struct SwingPoint
{
   double price;       // Price level of the swing
   int    barIndex;    // Bar index (shift from current bar)
   bool   isHigh;      // true = swing high, false = swing low
   datetime time;      // Time of the swing point
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
//| MarketStructure class                                            |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   int                  m_lookback;       // Number of candles to analyze
   int                  m_swingStrength;  // Bars on each side to confirm a swing
   string               m_symbol;         // Symbol to analyze
   ENUM_TIMEFRAMES      m_timeframe;      // Timeframe to analyze

   SwingPoint           m_swingHighs[];   // Detected swing highs (oldest first)
   SwingPoint           m_swingLows[];    // Detected swing lows (oldest first)
   StructureEvent       m_events[];       // Detected structure events
   ENUM_MARKET_STRUCTURE m_currentStructure; // Current market structure

   // Internal methods
   bool                 IsSwingHigh(int barIndex);
   bool                 IsSwingLow(int barIndex);
   void                 DetectSwingPoints(void);
   void                 AnalyzeStructure(void);
   void                 AddSwingHigh(double price, int barIndex, datetime time);
   void                 AddSwingLow(double price, int barIndex, datetime time);
   void                 AddEvent(ENUM_STRUCTURE_EVENT type, double level, int barIndex, datetime time);

public:
                        CMarketStructure(void);
                       ~CMarketStructure(void);

   // Initialization
   void                 Init(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, int swingStrength);

   // Main update - call this on each new bar
   void                 Update(void);

   // Getters
   ENUM_MARKET_STRUCTURE GetStructure(void) const { return m_currentStructure; }
   string               GetStructureString(void) const;
   int                  GetSwingHighCount(void) const { return ArraySize(m_swingHighs); }
   int                  GetSwingLowCount(void) const { return ArraySize(m_swingLows); }
   int                  GetEventCount(void) const { return ArraySize(m_events); }

   // Access individual swing points and events
   bool                 GetSwingHigh(int index, SwingPoint &point) const;
   bool                 GetSwingLow(int index, SwingPoint &point) const;
   bool                 GetLastEvent(StructureEvent &event) const;
   bool                 GetEvent(int index, StructureEvent &event) const;

   // Utility
   string               EventToString(ENUM_STRUCTURE_EVENT type) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure(void)
   : m_lookback(100),
     m_swingStrength(3),
     m_symbol(NULL),
     m_timeframe(PERIOD_CURRENT),
     m_currentStructure(MS_UNDEFINED)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure(void)
{
}

//+------------------------------------------------------------------+
//| Initialize the market structure detector                         |
//+------------------------------------------------------------------+
void CMarketStructure::Init(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, int swingStrength)
{
   m_symbol        = symbol;
   m_timeframe     = timeframe;
   m_lookback      = lookback;
   m_swingStrength = swingStrength;
   m_currentStructure = MS_UNDEFINED;
}

//+------------------------------------------------------------------+
//| Check if a bar is a swing high                                   |
//| A swing high has lower highs on both sides for swingStrength bars|
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingHigh(int barIndex)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   if(high == 0) return false;

   // Check bars to the left (older bars = higher index)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      double leftHigh = iHigh(m_symbol, m_timeframe, barIndex + i);
      if(leftHigh >= high) return false;
   }

   // Check bars to the right (newer bars = lower index)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      double rightHigh = iHigh(m_symbol, m_timeframe, barIndex - i);
      if(rightHigh >= high) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if a bar is a swing low                                    |
//| A swing low has higher lows on both sides for swingStrength bars |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingLow(int barIndex)
{
   double low = iLow(m_symbol, m_timeframe, barIndex);
   if(low == 0) return false;

   // Check bars to the left (older bars = higher index)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      double leftLow = iLow(m_symbol, m_timeframe, barIndex + i);
      if(leftLow <= low) return false;
   }

   // Check bars to the right (newer bars = lower index)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      double rightLow = iLow(m_symbol, m_timeframe, barIndex - i);
      if(rightLow <= low) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Add a swing high to the array                                    |
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
//| Add a swing low to the array                                     |
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
//| Add a structure event                                            |
//+------------------------------------------------------------------+
void CMarketStructure::AddEvent(ENUM_STRUCTURE_EVENT type, double level, int barIndex, datetime time)
{
   int size = ArraySize(m_events);
   ArrayResize(m_events, size + 1);
   m_events[size].type     = type;
   m_events[size].level    = level;
   m_events[size].barIndex = barIndex;
   m_events[size].time     = time;
}

//+------------------------------------------------------------------+
//| Detect all swing points within the lookback period               |
//+------------------------------------------------------------------+
void CMarketStructure::DetectSwingPoints(void)
{
   // Clear previous data
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);

   // We need swingStrength bars on each side, so valid range is
   // from m_swingStrength to (m_lookback - m_swingStrength)
   int startBar = m_swingStrength;
   int endBar   = m_lookback - m_swingStrength;

   if(endBar <= startBar)
      return;

   // Scan from oldest to newest so arrays are in chronological order
   for(int i = endBar; i >= startBar; i--)
   {
      datetime barTime = iTime(m_symbol, m_timeframe, i);

      if(IsSwingHigh(i))
      {
         double highPrice = iHigh(m_symbol, m_timeframe, i);
         AddSwingHigh(highPrice, i, barTime);
      }

      if(IsSwingLow(i))
      {
         double lowPrice = iLow(m_symbol, m_timeframe, i);
         AddSwingLow(lowPrice, i, barTime);
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze structure using swing points to find BOS and ChoCH       |
//|                                                                  |
//| Logic:                                                           |
//| - We maintain a running market structure state                   |
//| - We track the most recent significant swing high and swing low  |
//| - BOS = trend continuation break                                 |
//|   * Bullish BOS: price breaks above the last swing high while    |
//|     already in bullish structure (higher high confirmed)         |
//|   * Bearish BOS: price breaks below the last swing low while     |
//|     already in bearish structure (lower low confirmed)           |
//| - ChoCH = trend reversal break                                   |
//|   * Bullish ChoCH: price breaks above the last swing high while |
//|     in bearish structure (character change to bullish)            |
//|   * Bearish ChoCH: price breaks below the last swing low while  |
//|     in bullish structure (character change to bearish)            |
//+------------------------------------------------------------------+
void CMarketStructure::AnalyzeStructure(void)
{
   ArrayFree(m_events);
   m_currentStructure = MS_UNDEFINED;

   // We need at least 2 swing highs and 2 swing lows to begin analysis
   int highCount = ArraySize(m_swingHighs);
   int lowCount  = ArraySize(m_swingLows);

   if(highCount < 2 || lowCount < 2)
      return;

   // Merge swing highs and lows into a single chronological sequence
   // sorted by bar index descending (oldest first since higher barIndex = older)
   int totalSwings = highCount + lowCount;
   SwingPoint allSwings[];
   ArrayResize(allSwings, totalSwings);

   int idx = 0;
   for(int i = 0; i < highCount; i++)
   {
      allSwings[idx] = m_swingHighs[i];
      idx++;
   }
   for(int i = 0; i < lowCount; i++)
   {
      allSwings[idx] = m_swingLows[i];
      idx++;
   }

   // Sort by barIndex descending (oldest first) - simple bubble sort
   for(int i = 0; i < totalSwings - 1; i++)
   {
      for(int j = 0; j < totalSwings - i - 1; j++)
      {
         if(allSwings[j].barIndex < allSwings[j + 1].barIndex)
         {
            SwingPoint temp = allSwings[j];
            allSwings[j]     = allSwings[j + 1];
            allSwings[j + 1] = temp;
         }
      }
   }

   // Track the key levels for structure analysis
   double lastSwingHigh = 0;
   double lastSwingLow  = 0;
   bool   hasLastHigh   = false;
   bool   hasLastLow    = false;

   // Walk through the swing sequence from oldest to newest
   for(int i = 0; i < totalSwings; i++)
   {
      if(allSwings[i].isHigh)
      {
         // This is a swing high
         if(hasLastHigh && hasLastLow)
         {
            // Check if this swing high breaks above the previous swing high
            if(allSwings[i].price > lastSwingHigh)
            {
               if(m_currentStructure == MS_BULLISH || m_currentStructure == MS_UNDEFINED)
               {
                  // Bullish BOS - continuation of bullish structure
                  if(m_currentStructure == MS_BULLISH)
                     AddEvent(SE_BOS_BULL, lastSwingHigh, allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BULLISH;
               }
               else if(m_currentStructure == MS_BEARISH)
               {
                  // Bullish ChoCH - was bearish, now breaking above previous high
                  AddEvent(SE_CHOCH_BULL, lastSwingHigh, allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BULLISH;
               }
            }
         }

         // Update the last swing high
         lastSwingHigh = allSwings[i].price;
         hasLastHigh   = true;
      }
      else
      {
         // This is a swing low
         if(hasLastHigh && hasLastLow)
         {
            // Check if this swing low breaks below the previous swing low
            if(allSwings[i].price < lastSwingLow)
            {
               if(m_currentStructure == MS_BEARISH || m_currentStructure == MS_UNDEFINED)
               {
                  // Bearish BOS - continuation of bearish structure
                  if(m_currentStructure == MS_BEARISH)
                     AddEvent(SE_BOS_BEAR, lastSwingLow, allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BEARISH;
               }
               else if(m_currentStructure == MS_BULLISH)
               {
                  // Bearish ChoCH - was bullish, now breaking below previous low
                  AddEvent(SE_CHOCH_BEAR, lastSwingLow, allSwings[i].barIndex, allSwings[i].time);
                  m_currentStructure = MS_BEARISH;
               }
            }
         }

         // Update the last swing low
         lastSwingLow = allSwings[i].price;
         hasLastLow   = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Main update function - detects swing points and analyzes         |
//| structure. Call on each new bar.                                  |
//+------------------------------------------------------------------+
void CMarketStructure::Update(void)
{
   DetectSwingPoints();
   AnalyzeStructure();
}

//+------------------------------------------------------------------+
//| Return structure as readable string                              |
//+------------------------------------------------------------------+
string CMarketStructure::GetStructureString(void) const
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
//| Get a swing high by index                                        |
//+------------------------------------------------------------------+
bool CMarketStructure::GetSwingHigh(int index, SwingPoint &point) const
{
   if(index < 0 || index >= ArraySize(m_swingHighs))
      return false;
   point = m_swingHighs[index];
   return true;
}

//+------------------------------------------------------------------+
//| Get a swing low by index                                         |
//+------------------------------------------------------------------+
bool CMarketStructure::GetSwingLow(int index, SwingPoint &point) const
{
   if(index < 0 || index >= ArraySize(m_swingLows))
      return false;
   point = m_swingLows[index];
   return true;
}

//+------------------------------------------------------------------+
//| Get the most recent structure event                              |
//+------------------------------------------------------------------+
bool CMarketStructure::GetLastEvent(StructureEvent &event) const
{
   int size = ArraySize(m_events);
   if(size == 0) return false;
   event = m_events[size - 1];
   return true;
}

//+------------------------------------------------------------------+
//| Get a structure event by index                                   |
//+------------------------------------------------------------------+
bool CMarketStructure::GetEvent(int index, StructureEvent &event) const
{
   if(index < 0 || index >= ArraySize(m_events))
      return false;
   event = m_events[index];
   return true;
}

//+------------------------------------------------------------------+
//| Convert event type to string                                     |
//+------------------------------------------------------------------+
string CMarketStructure::EventToString(ENUM_STRUCTURE_EVENT type) const
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
//+------------------------------------------------------------------+
