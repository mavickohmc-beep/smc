//+------------------------------------------------------------------+
//|                                          TrianglePatterns.mqh    |
//|        Triangle Pattern Detection - Multi-Candidate Approach     |
//|                                                                  |
//| Builds 5 triangle candidates from different time windows of      |
//| swing data. Ranks by R-squared fit to find the most probable     |
//| triangle, then evaluates current price for breakout/validation.  |
//+------------------------------------------------------------------+
#property copyright "SMC EA"
#property version   "2.00"

#include "MarketStructure.mqh"

#define TRIANGLE_CANDIDATES 5

//--- Triangle pattern types
enum ENUM_TRIANGLE_PATTERN
{
   TP_NONE,                // No triangle detected
   TP_ASCENDING,           // Ascending triangle (flat highs, rising lows)
   TP_DESCENDING,          // Descending triangle (falling highs, flat lows)
   TP_SYMMETRICAL,         // Symmetrical triangle (falling highs, rising lows)
   TP_RISING_WEDGE,        // Rising wedge (both rising, converging)
   TP_FALLING_WEDGE        // Falling wedge (both falling, converging)
};

//--- Price position relative to the triangle
enum ENUM_PRICE_POSITION
{
   PP_INSIDE,              // Price is inside the triangle
   PP_BREAKOUT_ABOVE,      // Price broke above the upper trendline
   PP_BREAKOUT_BELOW,      // Price broke below the lower trendline
   PP_NO_TRIANGLE          // No triangle to evaluate
};

//--- Market strength when inside triangle
enum ENUM_TRIANGLE_STRENGTH
{
   TS_STRONG_BULLISH,      // Price in top 20% of triangle
   TS_BULLISH,             // Price in 60-80% range
   TS_NEUTRAL,             // Price in 40-60% range
   TS_BEARISH,             // Price in 20-40% range
   TS_STRONG_BEARISH,      // Price in bottom 20%
   TS_NOT_APPLICABLE       // No triangle or price outside
};

//--- Breakout validation against expected pattern direction
enum ENUM_BREAKOUT_VALIDATION
{
   BV_NOT_APPLICABLE,      // No breakout or no triangle
   BV_VALIDATED,           // Breakout matches expected direction
   BV_INVALIDATED,         // Breakout opposes expected direction
   BV_NEUTRAL              // Pattern has no strong directional bias (symmetrical)
};

//--- Trendline data from linear regression
struct TrendlineData
{
   double slope;           // Price change per bar toward present (positive = rising)
   double intercept;       // Regression y-value at x=0 (oldest point's bar position)
   double rSquared;        // R-squared goodness of fit (0.0 to 1.0)
   int    pointCount;      // Number of swing points used in regression
   int    maxBarIndex;     // Highest barIndex among input points (oldest bar)
};

//--- A single triangle candidate
struct TriangleCandidate
{
   ENUM_TRIANGLE_PATTERN pattern;
   TrendlineData         highTrend;
   TrendlineData         lowTrend;
   double                upperAtCurrent;   // Upper trendline projected at bar 0
   double                lowerAtCurrent;   // Lower trendline projected at bar 0
   double                apexBarDistance;   // Bars until trendlines converge
   double                combinedR2;       // (highR2 + lowR2) / 2
   double                score;            // Composite ranking score
   bool                  isValid;          // Enough points, converges, upper > lower
   int                   windowBarStart;   // Lowest barIndex in window (newest end)
   int                   windowBarEnd;     // Highest barIndex in window (oldest end)
   datetime              timeStart;        // Time of newest bar in window
   datetime              timeEnd;          // Time of oldest bar in window
};

//--- Full analysis result from the best candidate
struct TriangleResult
{
   ENUM_TRIANGLE_PATTERN    pattern;
   ENUM_PRICE_POSITION      pricePosition;
   ENUM_TRIANGLE_STRENGTH   strength;
   ENUM_BREAKOUT_VALIDATION validation;
   int                      candidateIndex;   // 1-5 (1=newest, 5=oldest), 0=none selected
   double                   upperLevel;       // Upper trendline at current bar
   double                   lowerLevel;       // Lower trendline at current bar
   double                   currentPrice;
   double                   apexBarDistance;
   double                   highSlope;
   double                   lowSlope;
   double                   highR2;
   double                   lowR2;
   double                   breakoutPercent;  // How far price is beyond boundary (%)
   // For drawing trendlines
   datetime                 trendStartTime;   // Oldest bar time in selected window
   double                   upperAtStart;     // Upper trendline value at trendStartTime
   double                   lowerAtStart;     // Lower trendline value at trendStartTime
};

//+------------------------------------------------------------------+
//| CTrianglePattern class                                           |
//+------------------------------------------------------------------+
class CTrianglePattern
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   int                  m_minSwingPoints;   // Min swing points per side for a valid candidate
   double               m_flatThreshold;    // Normalized slope below this = flat
   double               m_breakoutMargin;   // % beyond trendline to confirm breakout

   TriangleCandidate    m_candidates[TRIANGLE_CANDIDATES];
   int                  m_validCount;       // How many candidates are valid
   int                  m_bestIndex;        // Index of best candidate (0-4), -1 if none
   TriangleResult       m_result;           // Final result from best candidate

   // Linear regression: y = slope * x + intercept, x = maxBar - barIndex
   bool                 LinearRegression(const SwingPoint &points[], int count,
                                         TrendlineData &result);

   // Classify pattern from trendline slopes
   ENUM_TRIANGLE_PATTERN ClassifyPattern(double highSlope, double lowSlope,
                                         double avgPrice);

   // Build all 5 candidates from swing point windows
   void                 BuildCandidates(const SwingPoint &highs[], int hCount,
                                        const SwingPoint &lows[], int lCount);

   // Score and select the best candidate
   int                  SelectBestCandidate(void);

   // Evaluate price position and breakout for the selected candidate
   void                 EvaluatePrice(int bestIdx);

   // Get expected breakout direction for a pattern
   ENUM_BREAKOUT_VALIDATION ValidateBreakout(ENUM_TRIANGLE_PATTERN pattern,
                                              ENUM_PRICE_POSITION position);

   // Project trendline value at a specific barIndex
   double               ProjectAt(const TrendlineData &trend, int barIndex);

public:
                        CTrianglePattern(void);
                       ~CTrianglePattern(void);

   // Initialization
   void                 Init(string symbol, ENUM_TIMEFRAMES timeframe,
                             int minSwingPoints = 3, double flatThresholdPct = 0.002,
                             double breakoutMarginPct = 0.15);

   // Main analysis - call after CMarketStructure::Update()
   void                 Analyze(CMarketStructure &ms);

   // Result from best candidate
   TriangleResult       GetResult(void) const { return m_result; }
   ENUM_TRIANGLE_PATTERN GetPattern(void) const { return m_result.pattern; }
   ENUM_PRICE_POSITION  GetPricePosition(void) const { return m_result.pricePosition; }
   ENUM_TRIANGLE_STRENGTH GetStrength(void) const { return m_result.strength; }
   ENUM_BREAKOUT_VALIDATION GetValidation(void) const { return m_result.validation; }

   // Access individual candidates (0=newest/Tri1, 4=oldest/Tri5)
   bool                 GetCandidate(int index, TriangleCandidate &cand) const;
   int                  GetValidCandidateCount(void) const { return m_validCount; }
   int                  GetBestCandidateIndex(void) const { return m_bestIndex; }

   // String conversions
   string               PatternToString(ENUM_TRIANGLE_PATTERN p) const;
   string               PositionToString(ENUM_PRICE_POSITION p) const;
   string               StrengthToString(ENUM_TRIANGLE_STRENGTH s) const;
   string               ValidationToString(ENUM_BREAKOUT_VALIDATION v) const;
   string               GetSummary(void) const;
   string               GetCandidatesSummary(void) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrianglePattern::CTrianglePattern(void)
   : m_symbol(NULL),
     m_timeframe(PERIOD_CURRENT),
     m_minSwingPoints(3),
     m_flatThreshold(0.002),
     m_breakoutMargin(0.15),
     m_validCount(0),
     m_bestIndex(-1)
{
   ZeroMemory(m_result);
   m_result.pattern       = TP_NONE;
   m_result.pricePosition = PP_NO_TRIANGLE;
   m_result.strength      = TS_NOT_APPLICABLE;
   m_result.validation    = BV_NOT_APPLICABLE;

   for(int i = 0; i < TRIANGLE_CANDIDATES; i++)
   {
      ZeroMemory(m_candidates[i]);
      m_candidates[i].isValid = false;
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrianglePattern::~CTrianglePattern(void)
{
}

//+------------------------------------------------------------------+
//| Initialize parameters                                            |
//+------------------------------------------------------------------+
void CTrianglePattern::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                            int minSwingPoints, double flatThresholdPct,
                            double breakoutMarginPct)
{
   m_symbol          = symbol;
   m_timeframe       = timeframe;
   m_minSwingPoints  = MathMax(minSwingPoints, 2);
   m_flatThreshold   = flatThresholdPct;
   m_breakoutMargin  = breakoutMarginPct;
}

//+------------------------------------------------------------------+
//| Linear regression on swing points                                |
//|                                                                  |
//| x = maxBarIndex - barIndex (so x grows toward present)           |
//| y = slope * x + intercept                                        |
//| Positive slope = prices rising toward present                    |
//+------------------------------------------------------------------+
bool CTrianglePattern::LinearRegression(const SwingPoint &points[], int count,
                                        TrendlineData &result)
{
   ZeroMemory(result);
   result.pointCount = count;

   if(count < 2)
      return false;

   int maxBar = 0;
   for(int i = 0; i < count; i++)
      if(points[i].barIndex > maxBar)
         maxBar = points[i].barIndex;

   result.maxBarIndex = maxBar;

   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;

   for(int i = 0; i < count; i++)
   {
      double x = (double)(maxBar - points[i].barIndex);
      double y = points[i].price;
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
      sumY2 += y * y;
   }

   double n = (double)count;
   double denom = n * sumX2 - sumX * sumX;

   if(MathAbs(denom) < 1e-10)
      return false;

   result.slope     = (n * sumXY - sumX * sumY) / denom;
   result.intercept = (sumY - result.slope * sumX) / n;

   // R-squared
   double ssTotal = sumY2 - (sumY * sumY) / n;
   if(MathAbs(ssTotal) < 1e-10)
   {
      result.rSquared = 1.0;
      return true;
   }

   double ssResidual = 0;
   for(int i = 0; i < count; i++)
   {
      double x = (double)(maxBar - points[i].barIndex);
      double predicted = result.slope * x + result.intercept;
      double residual  = points[i].price - predicted;
      ssResidual += residual * residual;
   }

   result.rSquared = 1.0 - (ssResidual / ssTotal);
   if(result.rSquared < 0) result.rSquared = 0;

   return true;
}

//+------------------------------------------------------------------+
//| Project a trendline value at a specific barIndex                  |
//| Uses: y = slope * (maxBarIndex - barIndex) + intercept           |
//+------------------------------------------------------------------+
double CTrianglePattern::ProjectAt(const TrendlineData &trend, int barIndex)
{
   double x = (double)(trend.maxBarIndex - barIndex);
   return trend.slope * x + trend.intercept;
}

//+------------------------------------------------------------------+
//| Classify pattern from normalized trendline slopes                |
//+------------------------------------------------------------------+
ENUM_TRIANGLE_PATTERN CTrianglePattern::ClassifyPattern(double highSlope, double lowSlope,
                                                        double avgPrice)
{
   if(avgPrice <= 0) return TP_NONE;

   double normHigh = highSlope / avgPrice;
   double normLow  = lowSlope / avgPrice;

   bool highFlat    = MathAbs(normHigh) < m_flatThreshold;
   bool lowFlat     = MathAbs(normLow)  < m_flatThreshold;
   bool highRising  = normHigh > m_flatThreshold;
   bool highFalling = normHigh < -m_flatThreshold;
   bool lowRising   = normLow > m_flatThreshold;
   bool lowFalling  = normLow < -m_flatThreshold;

   // Must be converging: upper slope < lower slope (in normalized terms)
   bool converging = (normHigh - normLow) < 0;
   if(!converging)
      return TP_NONE;

   if(highFlat && lowRising)    return TP_ASCENDING;
   if(highFalling && lowFlat)   return TP_DESCENDING;
   if(highFalling && lowRising) return TP_SYMMETRICAL;
   if(highRising && lowRising)  return TP_RISING_WEDGE;
   if(highFalling && lowFalling) return TP_FALLING_WEDGE;

   return TP_NONE;
}

//+------------------------------------------------------------------+
//| Build 5 triangle candidates using sliding time windows           |
//|                                                                  |
//| Window strategy:                                                 |
//| - Compute the full bar range covered by all swing points         |
//| - Each candidate covers ~40% of that range                       |
//| - Windows are evenly spaced so candidate 0 covers the newest     |
//|   bars and candidate 4 covers the oldest bars                    |
//| - Within each window, collect the swing highs and lows that      |
//|   fall in that bar range, then run regression + classify          |
//+------------------------------------------------------------------+
void CTrianglePattern::BuildCandidates(const SwingPoint &highs[], int hCount,
                                       const SwingPoint &lows[], int lCount)
{
   // Reset all candidates
   m_validCount = 0;
   for(int i = 0; i < TRIANGLE_CANDIDATES; i++)
   {
      ZeroMemory(m_candidates[i]);
      m_candidates[i].isValid = false;
      m_candidates[i].pattern = TP_NONE;
   }

   // Find the full bar index range across all swing points
   // barIndex: 0 = current bar, higher = older
   int minBar = 999999, maxBar = 0;
   for(int i = 0; i < hCount; i++)
   {
      if(highs[i].barIndex < minBar) minBar = highs[i].barIndex;
      if(highs[i].barIndex > maxBar) maxBar = highs[i].barIndex;
   }
   for(int i = 0; i < lCount; i++)
   {
      if(lows[i].barIndex < minBar) minBar = lows[i].barIndex;
      if(lows[i].barIndex > maxBar) maxBar = lows[i].barIndex;
   }

   int totalRange = maxBar - minBar;
   if(totalRange <= 0)
      return;

   // Window covers 40% of the total bar range
   int windowBars = (int)(totalRange * 0.40);
   if(windowBars < 1) windowBars = 1;

   // Step between window start positions
   double stepSize = 0;
   if(totalRange > windowBars)
      stepSize = (double)(totalRange - windowBars) / (double)(TRIANGLE_CANDIDATES - 1);

   for(int c = 0; c < TRIANGLE_CANDIDATES; c++)
   {
      int wStart = minBar + (int)(c * stepSize);
      int wEnd   = wStart + windowBars;
      if(wEnd > maxBar) wEnd = maxBar;

      m_candidates[c].windowBarStart = wStart;
      m_candidates[c].windowBarEnd   = wEnd;

      // Collect swing highs in this window
      SwingPoint hSubset[];
      int hSubCount = 0;
      for(int i = 0; i < hCount; i++)
      {
         if(highs[i].barIndex >= wStart && highs[i].barIndex <= wEnd)
         {
            ArrayResize(hSubset, hSubCount + 1);
            hSubset[hSubCount] = highs[i];
            hSubCount++;
         }
      }

      // Collect swing lows in this window
      SwingPoint lSubset[];
      int lSubCount = 0;
      for(int i = 0; i < lCount; i++)
      {
         if(lows[i].barIndex >= wStart && lows[i].barIndex <= wEnd)
         {
            ArrayResize(lSubset, lSubCount + 1);
            lSubset[lSubCount] = lows[i];
            lSubCount++;
         }
      }

      // Need minimum points on each side
      if(hSubCount < m_minSwingPoints || lSubCount < m_minSwingPoints)
         continue;

      // Store window times
      m_candidates[c].timeStart = iTime(m_symbol, m_timeframe, wEnd);   // oldest bar
      m_candidates[c].timeEnd   = iTime(m_symbol, m_timeframe, wStart); // newest bar

      // Run linear regression on both sides
      if(!LinearRegression(hSubset, hSubCount, m_candidates[c].highTrend))
         continue;
      if(!LinearRegression(lSubset, lSubCount, m_candidates[c].lowTrend))
         continue;

      // Compute average price for normalization
      double sumPrice = 0;
      for(int i = 0; i < hSubCount; i++) sumPrice += hSubset[i].price;
      for(int i = 0; i < lSubCount; i++) sumPrice += lSubset[i].price;
      double avgPrice = sumPrice / (hSubCount + lSubCount);

      // Classify the pattern
      m_candidates[c].pattern = ClassifyPattern(m_candidates[c].highTrend.slope,
                                                m_candidates[c].lowTrend.slope,
                                                avgPrice);

      if(m_candidates[c].pattern == TP_NONE)
         continue;

      // Project trendlines to bar 0 (current bar)
      double upper = ProjectAt(m_candidates[c].highTrend, 0);
      double lower = ProjectAt(m_candidates[c].lowTrend, 0);

      // Trendlines must not have crossed yet at current bar
      if(upper <= lower)
      {
         // Triangle has expired (apex passed). Still useful for breakout
         // detection if price moved away before the cross. Apply a penalty
         // but don't fully discard.
         m_candidates[c].upperAtCurrent = upper;
         m_candidates[c].lowerAtCurrent = lower;
         m_candidates[c].combinedR2 = (m_candidates[c].highTrend.rSquared +
                                       m_candidates[c].lowTrend.rSquared) / 2.0;

         int totalPts = hSubCount + lSubCount;
         m_candidates[c].score = m_candidates[c].combinedR2 *
                                 (1.0 + 0.05 * (totalPts - 2 * m_minSwingPoints)) *
                                 0.3; // Heavy penalty for crossed trendlines
         m_candidates[c].isValid = true;
         m_candidates[c].apexBarDistance = 0;
         m_validCount++;
         continue;
      }

      m_candidates[c].upperAtCurrent = upper;
      m_candidates[c].lowerAtCurrent = lower;
      m_candidates[c].combinedR2 = (m_candidates[c].highTrend.rSquared +
                                    m_candidates[c].lowTrend.rSquared) / 2.0;

      // Apex distance: bars until trendlines meet
      // gap shrinks by (lowSlope - highSlope) per bar forward
      double gapNow  = upper - lower;
      double gapRate = m_candidates[c].lowTrend.slope - m_candidates[c].highTrend.slope;
      if(gapRate > 0)
         m_candidates[c].apexBarDistance = gapNow / gapRate;
      else
         m_candidates[c].apexBarDistance = 9999;

      // Composite score: R² fit quality * data richness bonus
      int totalPts = hSubCount + lSubCount;
      m_candidates[c].score = m_candidates[c].combinedR2 *
                              (1.0 + 0.05 * (totalPts - 2 * m_minSwingPoints));

      m_candidates[c].isValid = true;
      m_validCount++;
   }
}

//+------------------------------------------------------------------+
//| Select the best candidate by highest composite score             |
//| Returns index (0-4) or -1 if none valid                          |
//+------------------------------------------------------------------+
int CTrianglePattern::SelectBestCandidate(void)
{
   m_bestIndex = -1;
   double bestScore = 0;

   for(int i = 0; i < TRIANGLE_CANDIDATES; i++)
   {
      if(!m_candidates[i].isValid)
         continue;
      if(m_candidates[i].score > bestScore)
      {
         bestScore = m_candidates[i].score;
         m_bestIndex = i;
      }
   }

   return m_bestIndex;
}

//+------------------------------------------------------------------+
//| Evaluate current price against the selected candidate            |
//| Determines: inside/breakout, strength, and breakout validation   |
//+------------------------------------------------------------------+
void CTrianglePattern::EvaluatePrice(int bestIdx)
{
   if(bestIdx < 0 || bestIdx >= TRIANGLE_CANDIDATES || !m_candidates[bestIdx].isValid)
      return;

   TriangleCandidate &cand = m_candidates[bestIdx];

   double upper   = cand.upperAtCurrent;
   double lower   = cand.lowerAtCurrent;
   double current = iClose(m_symbol, m_timeframe, 0);

   m_result.pattern         = cand.pattern;
   m_result.candidateIndex  = bestIdx + 1; // 1-based for display
   m_result.upperLevel      = upper;
   m_result.lowerLevel      = lower;
   m_result.currentPrice    = current;
   m_result.apexBarDistance  = cand.apexBarDistance;
   m_result.highSlope       = cand.highTrend.slope;
   m_result.lowSlope        = cand.lowTrend.slope;
   m_result.highR2          = cand.highTrend.rSquared;
   m_result.lowR2           = cand.lowTrend.rSquared;

   // Drawing data: trendline start at the oldest bar of the candidate's window
   int drawBar = cand.windowBarEnd; // Oldest bar in window
   m_result.trendStartTime = cand.timeStart;
   m_result.upperAtStart   = ProjectAt(cand.highTrend, drawBar);
   m_result.lowerAtStart   = ProjectAt(cand.lowTrend, drawBar);

   // Compute breakout buffer
   double avgLevel = (upper + lower) / 2.0;
   if(avgLevel <= 0) avgLevel = current;
   double breakoutBuffer = avgLevel * (m_breakoutMargin / 100.0);

   // Handle crossed trendlines (expired triangle) - any position is a breakout
   if(upper <= lower)
   {
      if(current >= upper)
      {
         m_result.pricePosition   = PP_BREAKOUT_ABOVE;
         m_result.breakoutPercent = ((current - upper) / upper) * 100.0;
      }
      else
      {
         m_result.pricePosition   = PP_BREAKOUT_BELOW;
         m_result.breakoutPercent = ((lower - current) / lower) * 100.0;
      }
      m_result.strength  = TS_NOT_APPLICABLE;
      m_result.validation = ValidateBreakout(cand.pattern, m_result.pricePosition);
      return;
   }

   // Normal triangle (upper > lower)
   if(current > upper + breakoutBuffer)
   {
      m_result.pricePosition   = PP_BREAKOUT_ABOVE;
      m_result.strength        = TS_NOT_APPLICABLE;
      m_result.breakoutPercent = ((current - upper) / upper) * 100.0;
      m_result.validation      = ValidateBreakout(cand.pattern, PP_BREAKOUT_ABOVE);
   }
   else if(current < lower - breakoutBuffer)
   {
      m_result.pricePosition   = PP_BREAKOUT_BELOW;
      m_result.strength        = TS_NOT_APPLICABLE;
      m_result.breakoutPercent = ((lower - current) / lower) * 100.0;
      m_result.validation      = ValidateBreakout(cand.pattern, PP_BREAKOUT_BELOW);
   }
   else
   {
      // Inside the triangle
      m_result.pricePosition   = PP_INSIDE;
      m_result.breakoutPercent = 0;
      m_result.validation      = BV_NOT_APPLICABLE;

      double range = upper - lower;
      if(range > 0)
      {
         double ratio = (current - lower) / range;
         if(ratio >= 0.80)      m_result.strength = TS_STRONG_BULLISH;
         else if(ratio >= 0.60) m_result.strength = TS_BULLISH;
         else if(ratio >= 0.40) m_result.strength = TS_NEUTRAL;
         else if(ratio >= 0.20) m_result.strength = TS_BEARISH;
         else                   m_result.strength = TS_STRONG_BEARISH;
      }
      else
      {
         m_result.strength = TS_NEUTRAL;
      }
   }
}

//+------------------------------------------------------------------+
//| Validate a breakout against the expected pattern direction       |
//|                                                                  |
//| Ascending  -> expects breakout UP   (bullish)                    |
//| Descending -> expects breakout DOWN (bearish)                    |
//| Symmetrical-> either direction valid (neutral)                   |
//| Rising wedge  -> expects breakout DOWN (bearish reversal)        |
//| Falling wedge -> expects breakout UP   (bullish reversal)        |
//+------------------------------------------------------------------+
ENUM_BREAKOUT_VALIDATION CTrianglePattern::ValidateBreakout(ENUM_TRIANGLE_PATTERN pattern,
                                                             ENUM_PRICE_POSITION position)
{
   if(position != PP_BREAKOUT_ABOVE && position != PP_BREAKOUT_BELOW)
      return BV_NOT_APPLICABLE;

   switch(pattern)
   {
      case TP_ASCENDING:
         return (position == PP_BREAKOUT_ABOVE) ? BV_VALIDATED : BV_INVALIDATED;

      case TP_DESCENDING:
         return (position == PP_BREAKOUT_BELOW) ? BV_VALIDATED : BV_INVALIDATED;

      case TP_SYMMETRICAL:
         return BV_NEUTRAL;

      case TP_RISING_WEDGE:
         return (position == PP_BREAKOUT_BELOW) ? BV_VALIDATED : BV_INVALIDATED;

      case TP_FALLING_WEDGE:
         return (position == PP_BREAKOUT_ABOVE) ? BV_VALIDATED : BV_INVALIDATED;

      default:
         return BV_NOT_APPLICABLE;
   }
}

//+------------------------------------------------------------------+
//| Main analysis function                                           |
//| 1. Extract swing data from CMarketStructure                      |
//| 2. Build 5 candidates across different time windows              |
//| 3. Select the best by composite score                            |
//| 4. Evaluate current price for breakout / strength                |
//+------------------------------------------------------------------+
void CTrianglePattern::Analyze(CMarketStructure &ms)
{
   // Reset result
   ZeroMemory(m_result);
   m_result.pattern       = TP_NONE;
   m_result.pricePosition = PP_NO_TRIANGLE;
   m_result.strength      = TS_NOT_APPLICABLE;
   m_result.validation    = BV_NOT_APPLICABLE;
   m_result.candidateIndex = 0;
   m_bestIndex = -1;
   m_validCount = 0;

   int highCount = ms.GetSwingHighCount();
   int lowCount  = ms.GetSwingLowCount();

   if(highCount < m_minSwingPoints || lowCount < m_minSwingPoints)
      return;

   // Extract swing highs
   SwingPoint highs[];
   ArrayResize(highs, highCount);
   for(int i = 0; i < highCount; i++)
      ms.GetSwingHigh(i, highs[i]);

   // Extract swing lows
   SwingPoint lows[];
   ArrayResize(lows, lowCount);
   for(int i = 0; i < lowCount; i++)
      ms.GetSwingLow(i, lows[i]);

   // Build 5 candidates
   BuildCandidates(highs, highCount, lows, lowCount);

   // Select the best
   int best = SelectBestCandidate();
   if(best < 0)
      return;

   // Evaluate current price
   EvaluatePrice(best);
}

//+------------------------------------------------------------------+
//| Get a specific candidate (0-4)                                   |
//+------------------------------------------------------------------+
bool CTrianglePattern::GetCandidate(int index, TriangleCandidate &cand) const
{
   if(index < 0 || index >= TRIANGLE_CANDIDATES)
      return false;
   cand = m_candidates[index];
   return true;
}

//+------------------------------------------------------------------+
//| Pattern to string                                                |
//+------------------------------------------------------------------+
string CTrianglePattern::PatternToString(ENUM_TRIANGLE_PATTERN p) const
{
   switch(p)
   {
      case TP_ASCENDING:     return "Ascending Triangle";
      case TP_DESCENDING:    return "Descending Triangle";
      case TP_SYMMETRICAL:   return "Symmetrical Triangle";
      case TP_RISING_WEDGE:  return "Rising Wedge";
      case TP_FALLING_WEDGE: return "Falling Wedge";
      case TP_NONE:          return "No Triangle";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| Price position to string                                         |
//+------------------------------------------------------------------+
string CTrianglePattern::PositionToString(ENUM_PRICE_POSITION p) const
{
   switch(p)
   {
      case PP_INSIDE:         return "Inside Triangle";
      case PP_BREAKOUT_ABOVE: return "BREAKOUT UP";
      case PP_BREAKOUT_BELOW: return "BREAKOUT DOWN";
      case PP_NO_TRIANGLE:    return "No Triangle";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| Market strength to string                                        |
//+------------------------------------------------------------------+
string CTrianglePattern::StrengthToString(ENUM_TRIANGLE_STRENGTH s) const
{
   switch(s)
   {
      case TS_STRONG_BULLISH: return "Strong Bullish";
      case TS_BULLISH:        return "Bullish";
      case TS_NEUTRAL:        return "Neutral";
      case TS_BEARISH:        return "Bearish";
      case TS_STRONG_BEARISH: return "Strong Bearish";
      case TS_NOT_APPLICABLE: return "N/A";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| Breakout validation to string                                    |
//+------------------------------------------------------------------+
string CTrianglePattern::ValidationToString(ENUM_BREAKOUT_VALIDATION v) const
{
   switch(v)
   {
      case BV_VALIDATED:       return "VALIDATED";
      case BV_INVALIDATED:     return "INVALIDATED";
      case BV_NEUTRAL:         return "Neutral";
      case BV_NOT_APPLICABLE:  return "N/A";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| Full summary of current analysis                                 |
//+------------------------------------------------------------------+
string CTrianglePattern::GetSummary(void) const
{
   if(m_result.pattern == TP_NONE)
      return "No triangle pattern detected";

   string s = StringFormat("Tri#%d %s (R²:%.2f/%.2f)",
                           m_result.candidateIndex,
                           PatternToString(m_result.pattern),
                           m_result.highR2, m_result.lowR2);

   if(m_result.pricePosition == PP_INSIDE)
   {
      s += " | Inside | " + StrengthToString(m_result.strength);
      s += StringFormat(" | Apex ~%.0f bars", m_result.apexBarDistance);
   }
   else if(m_result.pricePosition == PP_BREAKOUT_ABOVE ||
           m_result.pricePosition == PP_BREAKOUT_BELOW)
   {
      s += " | " + PositionToString(m_result.pricePosition);
      s += StringFormat(" (%.2f%%)", m_result.breakoutPercent);
      s += " | " + ValidationToString(m_result.validation);
   }

   return s;
}

//+------------------------------------------------------------------+
//| Brief summary of all 5 candidates for dashboard display          |
//| Format: "1:Asc* 2:--- 3:Sym 4:Des 5:---"                       |
//| Asterisk marks the selected best candidate                       |
//+------------------------------------------------------------------+
string CTrianglePattern::GetCandidatesSummary(void) const
{
   string s = "";

   for(int i = 0; i < TRIANGLE_CANDIDATES; i++)
   {
      if(i > 0) s += " ";
      s += IntegerToString(i + 1) + ":";

      if(!m_candidates[i].isValid)
      {
         s += "---";
      }
      else
      {
         switch(m_candidates[i].pattern)
         {
            case TP_ASCENDING:     s += "Asc"; break;
            case TP_DESCENDING:    s += "Des"; break;
            case TP_SYMMETRICAL:   s += "Sym"; break;
            case TP_RISING_WEDGE:  s += "RW";  break;
            case TP_FALLING_WEDGE: s += "FW";  break;
            default:               s += "---"; break;
         }
         if(i == m_bestIndex)
            s += "*";
      }
   }

   return s;
}
//+------------------------------------------------------------------+
