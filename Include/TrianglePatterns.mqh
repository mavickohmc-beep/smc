//+------------------------------------------------------------------+
//|                                          TrianglePatterns.mqh    |
//|             Triangle Chart Pattern Detection via Trendline Slopes |
//+------------------------------------------------------------------+
#property copyright "SMC EA"
#property version   "1.00"

#include "MarketStructure.mqh"

//--- Triangle pattern types
enum ENUM_TRIANGLE_PATTERN
{
   TP_NONE,                // No triangle detected
   TP_ASCENDING,           // Ascending triangle (flat highs, rising lows)
   TP_DESCENDING,          // Descending triangle (falling highs, flat lows)
   TP_SYMMETRICAL,         // Symmetrical triangle (falling highs, rising lows)
   TP_RISING_WEDGE,        // Rising wedge (rising highs, rising lows - converging)
   TP_FALLING_WEDGE        // Falling wedge (falling highs, falling lows - converging)
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
   TS_STRONG_BULLISH,      // Price hugging upper boundary
   TS_BULLISH,             // Price in upper half
   TS_NEUTRAL,             // Price near midpoint
   TS_BEARISH,             // Price in lower half
   TS_STRONG_BEARISH,      // Price hugging lower boundary
   TS_NOT_APPLICABLE       // No triangle or price outside
};

//--- Trendline data from linear regression
struct TrendlineData
{
   double slope;           // Slope (price change per bar, negative barIndex direction)
   double intercept;       // Y-intercept (projected price at bar 0)
   double rSquared;        // R-squared goodness of fit (0.0 to 1.0)
   int    pointCount;      // Number of swing points used
};

//--- Full triangle analysis result
struct TriangleResult
{
   ENUM_TRIANGLE_PATTERN   pattern;
   ENUM_PRICE_POSITION     pricePosition;
   ENUM_TRIANGLE_STRENGTH  strength;
   double                  upperLevel;     // Upper trendline at current bar
   double                  lowerLevel;     // Lower trendline at current bar
   double                  currentPrice;   // Current close price
   double                  apexBarDistance; // Bars until trendlines converge (apex)
   double                  highSlope;      // Slope of swing high trendline
   double                  lowSlope;       // Slope of swing low trendline
   double                  highR2;         // R-squared for high trendline
   double                  lowR2;          // R-squared for low trendline
   double                  breakoutPercent;// How far price is beyond the boundary (%)
};

//+------------------------------------------------------------------+
//| CTrianglePattern class                                           |
//+------------------------------------------------------------------+
class CTrianglePattern
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   int                  m_minSwingPoints;  // Minimum swing points per side for a valid triangle
   double               m_flatThreshold;   // Slope threshold for "flat" (as % of avg price per bar)
   double               m_convergeFactor;  // Max ratio of slopes for convergence in wedges
   double               m_minR2;           // Minimum R-squared to trust the trendline
   double               m_breakoutMargin;  // % beyond trendline to confirm breakout

   TrendlineData        m_highTrend;       // Linear regression on swing highs
   TrendlineData        m_lowTrend;        // Linear regression on swing lows
   TriangleResult       m_result;          // Latest analysis result

   // Linear regression: fits price = slope * x + intercept
   // x values are the bar indices (higher = older) mapped to sequential 0,1,2,...
   // We regress against sequential index so slope is in price-per-swing-point units,
   // then convert to price-per-bar for trendline projection.
   bool                 LinearRegression(const SwingPoint &points[], int count,
                                         TrendlineData &result);

   // Classify the pattern based on slopes
   ENUM_TRIANGLE_PATTERN ClassifyPattern(double highSlope, double lowSlope,
                                         double avgPrice);

   // Project trendline value at a given bar index
   double               ProjectTrendline(const TrendlineData &trend, int barIndex);

public:
                        CTrianglePattern(void);
                       ~CTrianglePattern(void);

   // Initialization
   void                 Init(string symbol, ENUM_TIMEFRAMES timeframe,
                             int minSwingPoints = 3, double flatThresholdPct = 0.002,
                             double minR2 = 0.60, double breakoutMarginPct = 0.1);

   // Main analysis - pass swing data from CMarketStructure
   void                 Analyze(CMarketStructure &ms);

   // Getters
   TriangleResult       GetResult(void) const { return m_result; }
   ENUM_TRIANGLE_PATTERN GetPattern(void) const { return m_result.pattern; }
   ENUM_PRICE_POSITION  GetPricePosition(void) const { return m_result.pricePosition; }
   ENUM_TRIANGLE_STRENGTH GetStrength(void) const { return m_result.strength; }

   // String conversions
   string               PatternToString(ENUM_TRIANGLE_PATTERN p) const;
   string               PositionToString(ENUM_PRICE_POSITION p) const;
   string               StrengthToString(ENUM_TRIANGLE_STRENGTH s) const;
   string               GetSummary(void) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrianglePattern::CTrianglePattern(void)
   : m_symbol(NULL),
     m_timeframe(PERIOD_CURRENT),
     m_minSwingPoints(3),
     m_flatThreshold(0.002),
     m_convergeFactor(0.7),
     m_minR2(0.60),
     m_breakoutMargin(0.1)
{
   ZeroMemory(m_highTrend);
   ZeroMemory(m_lowTrend);
   ZeroMemory(m_result);
   m_result.pattern       = TP_NONE;
   m_result.pricePosition = PP_NO_TRIANGLE;
   m_result.strength      = TS_NOT_APPLICABLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrianglePattern::~CTrianglePattern(void)
{
}

//+------------------------------------------------------------------+
//| Initialize parameters                                            |
//| flatThresholdPct: slope below this (as fraction of avg price     |
//|   per bar) is considered flat. e.g. 0.002 = 0.2% per bar        |
//| minR2: minimum R-squared to consider the trendline valid         |
//| breakoutMarginPct: % beyond trendline to confirm breakout        |
//+------------------------------------------------------------------+
void CTrianglePattern::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                            int minSwingPoints, double flatThresholdPct,
                            double minR2, double breakoutMarginPct)
{
   m_symbol          = symbol;
   m_timeframe       = timeframe;
   m_minSwingPoints  = MathMax(minSwingPoints, 2);
   m_flatThreshold   = flatThresholdPct;
   m_minR2           = minR2;
   m_breakoutMargin  = breakoutMarginPct;
}

//+------------------------------------------------------------------+
//| Linear regression on swing points                                |
//|                                                                  |
//| Points are in chronological order (oldest first = highest        |
//| barIndex). We use barIndex as the x-axis but invert it so that   |
//| x increases toward the present: x = maxBarIndex - barIndex       |
//| This way a positive slope means prices are rising toward now.    |
//+------------------------------------------------------------------+
bool CTrianglePattern::LinearRegression(const SwingPoint &points[], int count,
                                        TrendlineData &result)
{
   ZeroMemory(result);
   result.pointCount = count;

   if(count < 2)
      return false;

   // Find the max barIndex to invert the x axis
   int maxBar = 0;
   for(int i = 0; i < count; i++)
   {
      if(points[i].barIndex > maxBar)
         maxBar = points[i].barIndex;
   }

   // Compute sums for least-squares regression
   // y = slope * x + intercept, where x = (maxBar - barIndex)
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
      result.rSquared = 1.0; // All points at same price = perfect flat line
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

   // Convert slope from price-per-inverted-bar to price-per-bar toward present
   // Since x = maxBar - barIndex, and barIndex decreases toward present,
   // x increases toward present. So slope is already in the correct direction:
   // positive slope = price rising toward present.
   // But we need to store the intercept as the projected value at the current bar (bar 0).
   // At bar 0: x = maxBar - 0 = maxBar
   // projected price at bar 0 = slope * maxBar + intercept
   // We re-store intercept as the "base" and keep slope per-bar.

   return true;
}

//+------------------------------------------------------------------+
//| Project a trendline value at a specific barIndex                  |
//| x = maxBarUsedInRegression - barIndex                            |
//| But since we don't store maxBar, we recalculate:                 |
//| The regression was done with x = maxBar - barIndex               |
//| price = slope * (maxBar - barIndex) + intercept                  |
//| We store slope and intercept from the regression, and need the   |
//| maxBar. To handle this, Analyze() stores the projected values    |
//| directly. This method is a helper called during Analyze().       |
//+------------------------------------------------------------------+
double CTrianglePattern::ProjectTrendline(const TrendlineData &trend, int barIndex)
{
   // This is called with x already computed in Analyze
   // Not used standalone - projection is done inline in Analyze
   return 0;
}

//+------------------------------------------------------------------+
//| Classify the triangle pattern from trendline slopes              |
//|                                                                  |
//| Slopes are in price units per bar toward present:                |
//| positive = rising, negative = falling, ~0 = flat                 |
//|                                                                  |
//| Normalized slope = slope / avgPrice to get a dimensionless rate  |
//+------------------------------------------------------------------+
ENUM_TRIANGLE_PATTERN CTrianglePattern::ClassifyPattern(double highSlope, double lowSlope,
                                                        double avgPrice)
{
   if(avgPrice <= 0) return TP_NONE;

   // Normalize slopes to percentage of price per bar
   double normHigh = highSlope / avgPrice;
   double normLow  = lowSlope / avgPrice;

   bool highFlat    = MathAbs(normHigh) < m_flatThreshold;
   bool lowFlat     = MathAbs(normLow)  < m_flatThreshold;
   bool highRising  = normHigh > m_flatThreshold;
   bool highFalling = normHigh < -m_flatThreshold;
   bool lowRising   = normLow > m_flatThreshold;
   bool lowFalling  = normLow < -m_flatThreshold;

   // Lines must be converging for a triangle/wedge to form
   // i.e., highSlope < lowSlope (upper line falling relative to lower, or lower rising relative to upper)
   // In normalized terms: normHigh < normLow means converging
   bool converging = (normHigh - normLow) < 0;

   if(!converging)
      return TP_NONE;

   // Ascending triangle: flat resistance (highs), rising support (lows)
   if(highFlat && lowRising)
      return TP_ASCENDING;

   // Descending triangle: falling resistance (highs), flat support (lows)
   if(highFalling && lowFlat)
      return TP_DESCENDING;

   // Symmetrical triangle: falling highs, rising lows
   if(highFalling && lowRising)
      return TP_SYMMETRICAL;

   // Rising wedge: both rising but converging (highs rise slower than lows)
   if(highRising && lowRising)
      return TP_RISING_WEDGE;

   // Falling wedge: both falling but converging (highs fall faster than lows)
   if(highFalling && lowFalling)
      return TP_FALLING_WEDGE;

   return TP_NONE;
}

//+------------------------------------------------------------------+
//| Main analysis function                                           |
//| Reads swing data from the CMarketStructure instance and          |
//| performs triangle pattern detection                               |
//+------------------------------------------------------------------+
void CTrianglePattern::Analyze(CMarketStructure &ms)
{
   // Reset result
   ZeroMemory(m_result);
   m_result.pattern       = TP_NONE;
   m_result.pricePosition = PP_NO_TRIANGLE;
   m_result.strength      = TS_NOT_APPLICABLE;

   int highCount = ms.GetSwingHighCount();
   int lowCount  = ms.GetSwingLowCount();

   // Need minimum swing points on each side
   if(highCount < m_minSwingPoints || lowCount < m_minSwingPoints)
      return;

   // Extract swing highs into a local array
   SwingPoint highs[];
   ArrayResize(highs, highCount);
   for(int i = 0; i < highCount; i++)
      ms.GetSwingHigh(i, highs[i]);

   // Extract swing lows into a local array
   SwingPoint lows[];
   ArrayResize(lows, lowCount);
   for(int i = 0; i < lowCount; i++)
      ms.GetSwingLow(i, lows[i]);

   // Run linear regression on both sets
   if(!LinearRegression(highs, highCount, m_highTrend))
      return;
   if(!LinearRegression(lows, lowCount, m_lowTrend))
      return;

   // Check R-squared fitness
   if(m_highTrend.rSquared < m_minR2 || m_lowTrend.rSquared < m_minR2)
      return;

   // Compute average price for normalization
   double sumPrice = 0;
   for(int i = 0; i < highCount; i++)
      sumPrice += highs[i].price;
   for(int i = 0; i < lowCount; i++)
      sumPrice += lows[i].price;
   double avgPrice = sumPrice / (highCount + lowCount);

   // Classify the pattern
   ENUM_TRIANGLE_PATTERN pattern = ClassifyPattern(m_highTrend.slope, m_lowTrend.slope, avgPrice);

   if(pattern == TP_NONE)
      return;

   m_result.pattern   = pattern;
   m_result.highSlope = m_highTrend.slope;
   m_result.lowSlope  = m_lowTrend.slope;
   m_result.highR2    = m_highTrend.rSquared;
   m_result.lowR2     = m_lowTrend.rSquared;

   // Project trendlines to bar 0 (current bar)
   // Regression used x = maxBar - barIndex
   // At bar 0: x_high = maxHighBar, x_low = maxLowBar
   int maxHighBar = 0;
   for(int i = 0; i < highCount; i++)
      if(highs[i].barIndex > maxHighBar) maxHighBar = highs[i].barIndex;

   int maxLowBar = 0;
   for(int i = 0; i < lowCount; i++)
      if(lows[i].barIndex > maxLowBar) maxLowBar = lows[i].barIndex;

   double upperAtCurrent = m_highTrend.slope * (double)maxHighBar + m_highTrend.intercept;
   double lowerAtCurrent = m_lowTrend.slope  * (double)maxLowBar  + m_lowTrend.intercept;

   // Ensure upper > lower (sanity check)
   if(upperAtCurrent <= lowerAtCurrent)
   {
      // Trendlines have already crossed - pattern has expired
      m_result.pattern       = TP_NONE;
      m_result.pricePosition = PP_NO_TRIANGLE;
      m_result.strength      = TS_NOT_APPLICABLE;
      return;
   }

   m_result.upperLevel = upperAtCurrent;
   m_result.lowerLevel = lowerAtCurrent;

   // Compute approximate apex distance (bars until trendlines meet)
   // At bar b: upper = highSlope * (maxHighBar - b) + highIntercept
   //           lower = lowSlope * (maxLowBar - b) + lowIntercept
   // They meet when upper == lower. Using projected values per bar:
   // We already have upper and lower at bar 0. Per-bar change:
   // upper changes by -highSlope per bar forward (barIndex decreases)
   // lower changes by -lowSlope per bar forward
   // gap change per bar = (-highSlope) - (-lowSlope) = lowSlope - highSlope
   double gapNow       = upperAtCurrent - lowerAtCurrent;
   double gapChangeRate = m_lowTrend.slope - m_highTrend.slope;

   if(gapChangeRate > 0)
      m_result.apexBarDistance = gapNow / gapChangeRate;
   else
      m_result.apexBarDistance = 9999; // Not converging (shouldn't happen if pattern != NONE)

   // Current price
   double currentClose = iClose(m_symbol, m_timeframe, 0);
   m_result.currentPrice = currentClose;

   // Determine price position
   double breakoutBuffer = avgPrice * (m_breakoutMargin / 100.0);

   if(currentClose > upperAtCurrent + breakoutBuffer)
   {
      // Breakout above
      m_result.pricePosition  = PP_BREAKOUT_ABOVE;
      m_result.strength       = TS_NOT_APPLICABLE;
      m_result.breakoutPercent = ((currentClose - upperAtCurrent) / upperAtCurrent) * 100.0;
   }
   else if(currentClose < lowerAtCurrent - breakoutBuffer)
   {
      // Breakout below
      m_result.pricePosition  = PP_BREAKOUT_BELOW;
      m_result.strength       = TS_NOT_APPLICABLE;
      m_result.breakoutPercent = ((lowerAtCurrent - currentClose) / lowerAtCurrent) * 100.0;
   }
   else
   {
      // Inside the triangle
      m_result.pricePosition  = PP_INSIDE;
      m_result.breakoutPercent = 0;

      // Determine market strength by position within the triangle
      double range   = upperAtCurrent - lowerAtCurrent;
      double midLine = lowerAtCurrent + range * 0.5;

      if(range > 0)
      {
         double positionRatio = (currentClose - lowerAtCurrent) / range;

         if(positionRatio >= 0.80)
            m_result.strength = TS_STRONG_BULLISH;
         else if(positionRatio >= 0.60)
            m_result.strength = TS_BULLISH;
         else if(positionRatio >= 0.40)
            m_result.strength = TS_NEUTRAL;
         else if(positionRatio >= 0.20)
            m_result.strength = TS_BEARISH;
         else
            m_result.strength = TS_STRONG_BEARISH;
      }
      else
      {
         m_result.strength = TS_NEUTRAL;
      }
   }
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
//| Get a complete text summary of the current analysis              |
//+------------------------------------------------------------------+
string CTrianglePattern::GetSummary(void) const
{
   if(m_result.pattern == TP_NONE)
      return "No triangle pattern detected";

   string summary = PatternToString(m_result.pattern);

   if(m_result.pricePosition == PP_INSIDE)
   {
      summary += " | Inside | Strength: " + StrengthToString(m_result.strength);
      summary += StringFormat(" | Upper: %.5f | Lower: %.5f",
                              m_result.upperLevel, m_result.lowerLevel);
      summary += StringFormat(" | Apex in ~%.0f bars", m_result.apexBarDistance);
   }
   else if(m_result.pricePosition == PP_BREAKOUT_ABOVE)
   {
      summary += StringFormat(" | BREAKOUT UP (%.2f%% above)", m_result.breakoutPercent);
   }
   else if(m_result.pricePosition == PP_BREAKOUT_BELOW)
   {
      summary += StringFormat(" | BREAKOUT DOWN (%.2f%% below)", m_result.breakoutPercent);
   }

   return summary;
}
//+------------------------------------------------------------------+
