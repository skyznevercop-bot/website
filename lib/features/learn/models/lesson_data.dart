import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A single section within a lesson (heading + body text).
class LessonSection {
  final String heading;
  final String body;

  const LessonSection({required this.heading, required this.body});
}

/// A full lesson with multiple content sections.
class Lesson {
  final String id;
  final String title;
  final String subtitle;
  final int readMinutes;
  final List<LessonSection> sections;
  final List<String> keyTakeaways;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.readMinutes,
    required this.sections,
    required this.keyTakeaways,
  });
}

/// A learning path containing multiple lessons.
class LearningPath {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String tag;
  final List<Lesson> lessons;

  const LearningPath({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.tag,
    required this.lessons,
  });
}

/// A trading glossary term.
class GlossaryTerm {
  final String term;
  final String definition;

  const GlossaryTerm({required this.term, required this.definition});
}

// ═══════════════════════════════════════════════════════════════════════════════
// All Learning Paths & Lessons
// ═══════════════════════════════════════════════════════════════════════════════

final allLearningPaths = <LearningPath>[
  // ── Path 1: Getting Started ────────────────────────────────────────────────
  LearningPath(
    id: 'getting_started',
    title: 'Getting Started',
    description: 'Everything you need to start competing on SolFight.',
    icon: Icons.rocket_launch_rounded,
    color: AppTheme.success,
    tag: 'BEGINNER',
    lessons: [
      Lesson(
        id: 'gs_1',
        title: 'What is SolFight?',
        subtitle: 'The PvP trading arena on Solana',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Trading as a Competition',
            body:
                'SolFight is a player-vs-player trading arena built on Solana. Instead of trading against the market alone, you compete head-to-head against another trader. Both players start with the same \$1,000,000 demo balance and trade the same assets — BTC, ETH, and SOL — over a fixed timeframe. The player with the higher portfolio ROI at the end wins the match and takes the prize pool.',
          ),
          LessonSection(
            heading: 'How Matches Work',
            body:
                'You choose a match duration (15 minutes, 1 hour, 4 hours, 12 hours, or 24 hours) and a bet amount in USDC (\$5, \$10, \$50, \$100, or \$1,000). The system pairs you with an opponent who selected the same duration and bet. Once matched, you both enter the Arena — a real-time trading interface with live price feeds from Pyth, a candlestick chart, Quick Trade buttons, and an in-match chat window. You can go long or short on BTC, ETH, or SOL with up to 100x leverage.',
          ),
          LessonSection(
            heading: 'The Prize Pool',
            body:
                'Both players\' bet amounts are frozen from their platform balance when the match starts. The winner receives 90% of the total pot (both bets combined). The remaining 10% goes to the SolFight protocol as a rake. For example, in a \$100 match: the pot is \$200, the winner receives \$180, netting \$80 profit. The loser forfeits their \$100 bet. In a tie (both players finish within 0.001% ROI of each other), both players get their full bet returned.',
          ),
          LessonSection(
            heading: 'Why SolFight?',
            body:
                'Traditional trading can feel isolating. SolFight adds a competitive layer — you\'re not just trying to make money, you\'re trying to outperform a real human opponent under the same market conditions. It\'s like chess, but with candlestick charts. Your skill, strategy, and risk management directly determine the outcome. Every match is recorded on-chain for full transparency.',
          ),
        ],
        keyTakeaways: [
          'SolFight is PvP trading — you compete against another human, not the house.',
          'Both players trade BTC, ETH, and SOL with the same \$1M demo balance.',
          'Winner takes 90% of the combined pot; 10% goes to the protocol.',
          'Matches range from 15 minutes to 24 hours with bets from \$5 to \$1,000.',
        ],
      ),
      Lesson(
        id: 'gs_2',
        title: 'Connecting Your Wallet',
        subtitle: 'Set up your wallet and fund your account',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Supported Wallets',
            body:
                'SolFight supports four Solana wallets: Phantom, Solflare, Backpack, and Jupiter. Phantom is the most popular and works as a Chrome extension or mobile app. Any of these wallets can connect to SolFight — choose the one you\'re most comfortable with.',
          ),
          LessonSection(
            heading: 'Connecting Step-by-Step',
            body:
                '1. Click the "Connect Wallet" button in the top bar.\n2. Choose your wallet provider from the modal (Phantom, Solflare, Backpack, or Jupiter).\n3. Approve the connection request in your wallet extension.\n4. Your wallet address will appear in the top bar, and you\'ll be prompted to set a Gamer Tag (your display name on the platform).\n\nThat\'s it — you\'re now authenticated and ready to deposit funds.',
          ),
          LessonSection(
            heading: 'Platform Balance vs On-Chain Balance',
            body:
                'SolFight uses a platform balance system for instant gameplay. Your on-chain USDC stays in your wallet until you deposit it to the platform. Once deposited, your platform balance is used for match bets and winnings settle instantly — no waiting for blockchain confirmations during matches. You can withdraw your platform balance back to your wallet at any time.',
          ),
          LessonSection(
            heading: 'Depositing USDC',
            body:
                'To deposit, go to your Portfolio page and click "Deposit." Send USDC to the platform vault address, then confirm the transaction. The backend verifies your deposit on-chain and credits your platform balance instantly. SolFight currently runs on Solana Devnet, so you\'ll use Devnet USDC (free test tokens) — no real money at risk.',
          ),
        ],
        keyTakeaways: [
          'Four wallets supported: Phantom, Solflare, Backpack, and Jupiter.',
          'Your platform balance is separate from your on-chain wallet balance.',
          'Deposit USDC to your platform balance before joining matches.',
          'We\'re on Devnet — all funds are free test tokens, no real money.',
        ],
      ),
      Lesson(
        id: 'gs_3',
        title: 'Your First Match',
        subtitle: 'Join a queue and enter the Arena',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'The War Room (Play Screen)',
            body:
                'The Play screen is your launch pad. At the top, you\'ll see live platform stats — total players, matches played, and total volume. Below that are two selectors: match duration and bet amount. Duration options are 15 minutes, 1 hour, 4 hours, 12 hours, and 24 hours. Bet amounts are \$5, \$10, \$50, \$100, and \$1,000. Each duration chip shows a live badge with how many players are currently in that queue.',
          ),
          LessonSection(
            heading: 'Choosing Your Match',
            body:
                'Start with 15-minute or 1-hour matches to learn the ropes — they\'re fast, action-packed, and the most popular queues. Pick a bet amount you\'re comfortable with (start small at \$5 or \$10). Below the selectors, a match info card shows the total pot size, number of players in queue, and estimated wait time for your selection.',
          ),
          LessonSection(
            heading: 'Joining the Queue',
            body:
                'Click "Join Queue" to enter matchmaking. Your bet amount is immediately frozen from your platform balance (you need sufficient available balance). The system matches you with the next player who selected the same duration and bet — matchmaking is instant FIFO (first-in, first-out). While waiting, you\'ll see a timer tracking your queue time.',
          ),
          LessonSection(
            heading: 'The Face-Off & Arena Entry',
            body:
                'When an opponent is found, a face-off screen appears showing your gamer tag vs your opponent\'s. After a brief countdown, you\'re taken directly into the Arena. No manual deposit needed — your bet was already frozen when you joined the queue. The match timer starts immediately, and you\'ll see a dramatic 3-2-1 FIGHT countdown overlay before trading begins.',
          ),
        ],
        keyTakeaways: [
          'Start with 15m or 1h matches at \$5-\$10 bets to learn.',
          'Your bet is frozen from your platform balance when you join the queue.',
          'Matchmaking is instant — you\'re paired with the next player in the same queue.',
          'The match starts immediately after the face-off countdown.',
        ],
      ),
      Lesson(
        id: 'gs_4',
        title: 'Understanding the Arena UI',
        subtitle: 'Navigate charts, orders, positions, and the HUD',
        readMinutes: 5,
        sections: [
          LessonSection(
            heading: 'The Price Chart',
            body:
                'The center of the Arena is a real-time candlestick chart powered by LightWeight Charts. You can switch between BTC, ETH, and SOL using the asset bar above the chart. Price data updates every second with live market feeds. The chart displays 1-minute candles by default — use it to spot trends, support/resistance levels, and entry points.',
          ),
          LessonSection(
            heading: 'The Order Panel',
            body:
                'On the right side (desktop) or "Trade" tab (mobile), you\'ll find the order panel with two modes:\n\n• Quick Trade Grid: Six preset buttons for instant trades — Long/Short BTC at 10x, Long/Short ETH at 25x, Long/Short SOL at 50x. Perfect for fast entries.\n\n• Manual Order: Choose Long or Short, set your position size with percentage buttons (25%, 50%, 75%, MAX), pick leverage from 1x to 100x (with presets at 1x, 5x, 10x, 25x, 50x, 100x), and optionally set Stop Loss and Take Profit prices. A risk indicator shows Low, Medium, High, or Extreme based on your leverage. The order info card displays your entry price, liquidation price, liquidation distance %, and notional size before you confirm.',
          ),
          LessonSection(
            heading: 'Positions & Trade History',
            body:
                'The open positions panel shows all your active trades with live P&L updates — asset, direction (Long/Short), entry price, current price, size, leverage, and unrealized profit/loss in both dollars and percentage. Close any position instantly with the close button. Your closed trades history shows exit prices, realized P&L, and the close reason (manual, stop loss, take profit, liquidation, or match end).',
          ),
          LessonSection(
            heading: 'The Gaming HUD',
            body:
                'The Arena HUD keeps you informed at all times:\n\n• Match Timer: Countdown to match end at the top.\n• Player Cards: Your name, balance, and equity vs your opponent\'s gamer tag, ROI, and open position count.\n• Battle Bar: A tug-of-war indicator showing who\'s winning in real-time.\n• Events Feed: Live notifications for lead changes, big moves, opponent trades, liquidations, streaks, and phase transitions.\n• Match Phases: The match progresses through Opening Bell, Mid Game, Final Sprint (amber urgency), and Last Stand (red, final 10%). Phase banners slide down to announce transitions.\n• In-Match Chat: Message your opponent during the match.',
          ),
        ],
        keyTakeaways: [
          'Switch between BTC, ETH, SOL using the asset bar above the chart.',
          'Quick Trade Grid gives instant entries; Manual Order gives full control up to 100x leverage.',
          'Monitor the Battle Bar and opponent stats to adapt your strategy.',
          'Watch for match phase transitions — Final Sprint and Last Stand signal urgency.',
        ],
      ),
    ],
  ),

  // ── Path 2: Chart Analysis ─────────────────────────────────────────────────
  LearningPath(
    id: 'chart_analysis',
    title: 'Chart Analysis',
    description: 'Read price charts like a pro trader.',
    icon: Icons.candlestick_chart_rounded,
    color: AppTheme.info,
    tag: 'FUNDAMENTALS',
    lessons: [
      Lesson(
        id: 'ca_1',
        title: 'Candlestick Basics',
        subtitle: 'The building blocks of every chart',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'What is a Candlestick?',
            body:
                'A candlestick represents price movement over a specific time period. Each candle has four data points: Open (where the price started), Close (where it ended), High (the highest price reached), and Low (the lowest). A green candle means the price closed higher than it opened (bullish). A red candle means it closed lower (bearish). In the SolFight Arena, the chart displays 1-minute candles by default.',
          ),
          LessonSection(
            heading: 'The Body and Wicks',
            body:
                'The thick part of the candle is called the "body" — it shows the range between open and close. The thin lines extending above and below are "wicks" (or shadows) — they show the high and low extremes. A long wick means the price was rejected at that level. A candle with a small body and long wicks signals indecision.',
          ),
          LessonSection(
            heading: 'Key Candlestick Patterns',
            body:
                'Doji: Tiny body, long wicks — market is undecided. Often appears before reversals.\nHammer: Small body at the top, long lower wick — sellers pushed the price down but buyers fought back. Bullish reversal signal.\nEngulfing: A large candle that completely covers the previous candle\'s body. Bullish engulfing = buyers taking over. Bearish engulfing = sellers taking over.\nMorning Star: Three-candle reversal pattern — bearish candle, small indecision candle, then a strong bullish candle.',
          ),
          LessonSection(
            heading: 'Using Candles in SolFight',
            body:
                'In a 15-minute match, each 1-minute candle matters — look for reversal patterns near support or resistance to time your entries. In longer matches (4h+), observe the broader trend developing over many candles before committing to a direction. The SolFight chart updates live every second, so you\'ll see candles forming in real-time.',
          ),
        ],
        keyTakeaways: [
          'Green = bullish (price went up), Red = bearish (price went down).',
          'Long wicks show price rejection — important reversal signals.',
          'Learn to spot Doji, Hammer, and Engulfing patterns.',
          'Match your analysis timeframe to your match duration.',
        ],
      ),
      Lesson(
        id: 'ca_2',
        title: 'Support & Resistance',
        subtitle: 'Find the levels where price reacts',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'What is Support?',
            body:
                'Support is a price level where buying pressure consistently prevents the price from falling further. Think of it as a floor — the price bounces off it. Support forms because traders remember that the price reversed at that level before, so they place buy orders there. The more times a level holds, the stronger the support.',
          ),
          LessonSection(
            heading: 'What is Resistance?',
            body:
                'Resistance is the opposite — a ceiling where selling pressure stops the price from rising. Traders who bought lower take profits at resistance, and short sellers enter positions there. When price approaches resistance, expect it to slow down or reverse. A strong resistance level that has held multiple times is harder to break.',
          ),
          LessonSection(
            heading: 'Breakouts and Breakdowns',
            body:
                'When price finally breaks through support or resistance with conviction, it\'s called a breakout (up through resistance) or breakdown (down through support). These are powerful trading signals. The old resistance often becomes new support after a breakout, and vice versa. This "flip" is one of the most reliable patterns in trading.',
          ),
          LessonSection(
            heading: 'Applying to SolFight Matches',
            body:
                'Before opening any position, identify the nearest support and resistance levels on the chart. Go long near support (with a stop loss just below). Go short near resistance (with a stop loss just above). If you see a breakout, ride the momentum. These levels give you clear entry, exit, and risk points — use them with the TP/SL fields in the order panel.',
          ),
        ],
        keyTakeaways: [
          'Support = floor (price bounces up), Resistance = ceiling (price bounces down).',
          'The more times a level holds, the stronger it is.',
          'Broken resistance becomes new support (and vice versa).',
          'Set your Stop Loss and Take Profit around support/resistance levels.',
        ],
      ),
      Lesson(
        id: 'ca_3',
        title: 'Trend Identification',
        subtitle: 'Determine if the market is going up, down, or sideways',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Higher Highs, Higher Lows',
            body:
                'An uptrend is defined by a series of higher highs and higher lows. Each peak is higher than the last, and each dip doesn\'t go as low as the previous one. As long as this pattern holds, the trend is bullish. In an uptrend, favor long positions — "the trend is your friend."',
          ),
          LessonSection(
            heading: 'Lower Highs, Lower Lows',
            body:
                'A downtrend is the opposite — each peak is lower, and each dip goes deeper. This means sellers are in control. In a downtrend, favor short positions. Don\'t try to "catch the falling knife" — wait for a confirmed reversal before going long.',
          ),
          LessonSection(
            heading: 'Sideways (Range-Bound) Markets',
            body:
                'When price bounces between a clear support and resistance without making new highs or lows, it\'s ranging. In a range, you can buy at support and sell at resistance (mean-reversion strategy). Ranges eventually break — the breakout direction often leads to a strong move.',
          ),
          LessonSection(
            heading: 'Trend Trading in SolFight',
            body:
                'When a match starts, quickly assess the trend across all three assets. If BTC is in a clear uptrend, lean towards long positions. If it\'s a downtrend, lean short. If it\'s ranging, play the bounces between support and resistance. Having a directional bias from the start gives you a plan instead of random trades. Use the Quick Trade Grid for fast entries once you\'ve identified the trend.',
          ),
        ],
        keyTakeaways: [
          'Uptrend: higher highs + higher lows. Favor longs.',
          'Downtrend: lower highs + lower lows. Favor shorts.',
          'Range: play the bounces or wait for breakout.',
          'Assess the trend across BTC, ETH, and SOL as the match begins.',
        ],
      ),
      Lesson(
        id: 'ca_4',
        title: 'Volume & Momentum',
        subtitle: 'Confirm moves with trading activity',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Why Volume Matters',
            body:
                'Volume measures how much of an asset is being traded. High volume on a price move confirms that the move is real — many traders agree on the direction. Low volume moves are suspicious and more likely to reverse. Think of volume as conviction: loud crowds (high volume) mean the move has legs.',
          ),
          LessonSection(
            heading: 'Volume Divergence',
            body:
                'If price is making new highs but volume is decreasing, it\'s a warning sign — the uptrend is losing steam. This is called bearish divergence. Conversely, if price makes new lows on declining volume, sellers might be exhausted, signaling a potential bottom. Always compare price action with volume for the full picture.',
          ),
          LessonSection(
            heading: 'Momentum Concepts',
            body:
                'RSI (Relative Strength Index) measures how fast price is moving. Above 70 = overbought (may reverse down). Below 30 = oversold (may reverse up). MACD shows momentum direction changes — when the MACD line crosses above the signal line, it\'s bullish. While these indicators aren\'t displayed on the SolFight chart, understanding the concepts behind them helps you read raw price action and candle patterns more effectively.',
          ),
        ],
        keyTakeaways: [
          'High volume confirms price moves; low volume signals caution.',
          'Price + falling volume = weakening trend (divergence).',
          'RSI above 70 = overbought, below 30 = oversold.',
          'Apply momentum concepts by reading candle size and frequency.',
        ],
      ),
    ],
  ),

  // ── Path 3: Trading Strategies ─────────────────────────────────────────────
  LearningPath(
    id: 'strategies',
    title: 'Trading Strategies',
    description: 'Proven approaches for different match timeframes.',
    icon: Icons.psychology_rounded,
    color: AppTheme.warning,
    tag: 'INTERMEDIATE',
    lessons: [
      Lesson(
        id: 'st_1',
        title: 'Long vs Short',
        subtitle: 'Profit in both directions',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Going Long',
            body:
                'When you go long, you profit when the price goes up. In SolFight, opening a long position is a bet that the asset\'s price will increase during the match. Example: BTC is at \$100,000, you go long with 10x leverage and \$10,000 size. If BTC rises 1%, your position gains \$10,000 (10x your collateral\'s 1% move = 10% return on your margin).',
          ),
          LessonSection(
            heading: 'Going Short',
            body:
                'When you go short, you profit when the price drops. You\'re essentially selling first and buying back later at a lower price. Example: ETH is at \$2,000, you short with 5x leverage and \$20,000 size. If ETH drops 2%, your position gains \$2,000 (5x * 2% = 10% return on your margin). Shorting lets you profit in bear markets.',
          ),
          LessonSection(
            heading: 'When to Long vs Short',
            body:
                'Long when: the trend is bullish, price just bounced off support, or you see bullish reversal candles. Short when: the trend is bearish, price just hit resistance, or bearish candles form. In SolFight, being able to profit in both directions is your biggest advantage. Use the Quick Trade Grid for instant long/short entries, or the manual order panel when you want to fine-tune your leverage and size.',
          ),
        ],
        keyTakeaways: [
          'Long = profit when price goes up. Short = profit when price goes down.',
          'Leverage amplifies both gains AND losses.',
          'Always trade in the direction of the trend when possible.',
          'Quick Trade Grid gives instant long/short entries at preset leverage levels.',
        ],
      ),
      Lesson(
        id: 'st_2',
        title: 'Scalping (Short Timeframes)',
        subtitle: 'Quick trades, quick profits',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'What is Scalping?',
            body:
                'Scalping means making many small, fast trades to capture tiny price movements. Instead of one big trade, you might make 5-10 trades during a 15-minute match. Each trade targets a small gain (0.1-0.5%), but with leverage, these add up. Scalpers don\'t hold positions long — they get in, take profit, and move on.',
          ),
          LessonSection(
            heading: 'Scalping Setup',
            body:
                'Use higher leverage (10-50x) with smaller position sizes so a quick 0.1-0.3% move gives meaningful profit. Set tight stop losses (cut losers fast) and take profits quickly. Watch the 1-minute candles closely. Enter on bounces at micro-support levels or on small breakouts. The Quick Trade Grid is perfect for scalping — tap SOL Long 50x or ETH Short 25x for instant entries.',
          ),
          LessonSection(
            heading: 'Scalping in 15m Matches',
            body:
                'In a 15-minute SolFight match, scalping is the dominant strategy. You don\'t have time for big trends to develop — you need quick wins. Open a position, set a tight TP, close it within 1-2 minutes, then look for the next trade. The player who makes more correct micro-decisions wins. Keep an eye on the match phases — during Opening Bell, feel out the market; during Final Sprint, protect your gains.',
          ),
          LessonSection(
            heading: 'Common Mistakes',
            body:
                'Don\'t overtrade — if you\'re not seeing clear setups, wait. Don\'t use 100x leverage with your full balance — one tiny move against you triggers liquidation (at just ~0.9% adverse movement). Don\'t hold a losing scalp hoping it will recover — close it and find a new entry. Speed is important, but discipline is more important.',
          ),
        ],
        keyTakeaways: [
          'Scalping = many small, fast trades with leverage.',
          'Best for 15m and 1h matches — use Quick Trade Grid for speed.',
          'Cut losses fast, take profits quickly.',
          'Discipline > speed. Don\'t overtrade or over-leverage.',
        ],
      ),
      Lesson(
        id: 'st_3',
        title: 'Swing Trading (Long Timeframes)',
        subtitle: 'Ride the bigger moves',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'What is Swing Trading?',
            body:
                'Swing trading means holding positions for a longer period to capture larger price moves. In SolFight, this applies to 4h, 12h, and 24h matches. Instead of making 10 small trades, you might open 1-3 well-chosen positions and let them ride. The goal is to identify the dominant trend and position yourself early.',
          ),
          LessonSection(
            heading: 'Swing Setup',
            body:
                'Use moderate leverage (2-10x) with larger position sizes. Identify the trend on the chart, then wait for a pullback to enter. Set wider stop losses (give the trade room to breathe) and wider take profits (capture the full move). Patience is key — don\'t panic-close on small pullbacks. The SL/TP fields in the order panel let you automate your exits so you don\'t have to watch constantly.',
          ),
          LessonSection(
            heading: 'Multi-Asset Diversification',
            body:
                'In longer matches, consider splitting your balance across BTC, ETH, and SOL. If BTC is trending up and SOL is ranging, go long BTC and play SOL\'s range. This reduces your dependency on a single asset and smooths out your P&L. Check all three assets periodically using the asset bar — the market can shift during a 24h match.',
          ),
        ],
        keyTakeaways: [
          'Swing trading = fewer trades, bigger moves, more patience.',
          'Best for 4h, 12h, and 24h matches.',
          'Use moderate leverage (2-10x) and wider stops.',
          'Diversify across BTC, ETH, and SOL to reduce single-asset risk.',
        ],
      ),
      Lesson(
        id: 'st_4',
        title: 'Using Leverage Wisely',
        subtitle: 'Amplify without destroying',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'What Leverage Does',
            body:
                'Leverage multiplies your position size relative to your margin. With 10x leverage, a \$10,000 position controls \$100,000 worth of the asset. A 1% price move becomes a 10% gain or loss on your margin. SolFight offers leverage from 1x to 100x, with preset buttons at 1x, 5x, 10x, 25x, 50x, and 100x. A risk indicator shows your current risk level: Low, Medium, High, or Extreme.',
          ),
          LessonSection(
            heading: 'The Liquidation Trap',
            body:
                'In SolFight, liquidation triggers when you lose 90% of your position margin. The higher the leverage, the smaller the price move needed to hit that threshold:\n\n• 100x leverage: ~0.9% adverse move = liquidation\n• 50x leverage: ~1.8% adverse move = liquidation\n• 25x leverage: ~3.6% adverse move = liquidation\n• 10x leverage: ~9% adverse move = liquidation\n• 5x leverage: ~18% adverse move = liquidation\n\nMany beginners max out leverage and get liquidated on normal market noise. The order panel shows your exact liquidation price and distance before you confirm — always check it.',
          ),
          LessonSection(
            heading: 'Recommended Leverage by Match Type',
            body:
                '15-minute matches: 10-50x (price won\'t move much, you need leverage to generate returns)\n1-hour matches: 5-25x (moderate volatility)\n4-hour matches: 3-15x (more time for moves to develop)\n12-24 hour matches: 2-10x (big moves happen naturally, leverage less needed)\n\nA useful rule: the longer the match, the lower the leverage. Let time create the returns instead of leverage. The Quick Trade Grid defaults are tuned for each asset\'s volatility: BTC 10x, ETH 25x, SOL 50x.',
          ),
        ],
        keyTakeaways: [
          'Leverage goes from 1x to 100x with risk indicators (Low/Medium/High/Extreme).',
          'Liquidation triggers at 90% margin loss — check your liquidation price before confirming.',
          'Short matches: higher leverage. Long matches: lower leverage.',
          'Never go 100x with a large position — one bad tick wipes you out.',
        ],
      ),
    ],
  ),

  // ── Path 4: Risk Management ────────────────────────────────────────────────
  LearningPath(
    id: 'risk_management',
    title: 'Risk Management',
    description: 'Protect your capital and survive to win.',
    icon: Icons.shield_rounded,
    color: AppTheme.error,
    tag: 'ESSENTIAL',
    lessons: [
      Lesson(
        id: 'rm_1',
        title: 'Position Sizing',
        subtitle: 'How much to risk per trade',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'The Golden Rule',
            body:
                'Every match gives you a \$1,000,000 demo balance. Never risk more than 20-30% of it on a single trade. If you put everything into one position and it goes wrong, your equity tanks and recovery becomes nearly impossible. By keeping individual positions moderate, you can take multiple shots at winning. Even if 2 out of 5 trades fail, the remaining 3 can carry you to victory.',
          ),
          LessonSection(
            heading: 'The 25/50/75/MAX Buttons',
            body:
                'The Arena order panel has quick buttons: 25%, 50%, 75%, and MAX. These set your position size as a percentage of your available balance. For most situations, 25% is the safest starting size — it leaves room for 3 more positions. 50% is aggressive but acceptable for high-conviction setups. 75% and MAX should only be used when you see a textbook setup with volume confirmation. Start small, scale up as you gain confidence.',
          ),
          LessonSection(
            heading: 'Splitting Across Assets',
            body:
                'Instead of one 50% position on BTC, consider two 25% positions on BTC and ETH. If both assets are trending the same way, you benefit from both. If one underperforms, the other might compensate. Use the asset bar to quickly switch between assets and diversify your exposure within a match.',
          ),
        ],
        keyTakeaways: [
          'You start with \$1M demo balance each match — manage it wisely.',
          'Never risk more than 20-30% per trade.',
          'Start with the 25% button and scale up only with strong conviction.',
          'Spread across assets to reduce the impact of any single bad trade.',
        ],
      ),
      Lesson(
        id: 'rm_2',
        title: 'Stop Losses & Take Profits',
        subtitle: 'Automate your exits',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Why Stop Losses Matter',
            body:
                'A stop loss (SL) automatically closes your position if the price moves against you past a set level. Without one, a small loss can snowball into a liquidation. SolFight\'s backend monitors SL/TP levels every second and executes them automatically. Setting a stop loss removes emotion from the equation — the system exits for you when the trade thesis is wrong.',
          ),
          LessonSection(
            heading: 'Setting Effective Stop Losses',
            body:
                'In the order panel, toggle the SL/TP switch to reveal the price inputs. For longs, set your stop loss below the nearest support level. For shorts, set it above the nearest resistance. Don\'t set it too tight (normal noise will trigger it) or too wide (you\'ll lose too much). A good rule: place your stop at the level where, if hit, your trade idea is clearly wrong.',
          ),
          LessonSection(
            heading: 'Take Profit Targets',
            body:
                'A take profit (TP) automatically closes your position when it reaches a target gain. Aim for a reward-to-risk ratio of at least 2:1. If your stop loss risks \$50,000, your take profit should target at least \$100,000. This way, you only need to be right 40% of the time to come out ahead. The order panel validates that your TP is on the correct side of the entry price.',
          ),
        ],
        keyTakeaways: [
          'Always set a stop loss — the system checks SL/TP every second.',
          'Place stops below support (longs) or above resistance (shorts).',
          'Aim for 2:1 or better reward-to-risk ratio on your take profits.',
          'SL/TP lets you set and forget — focus on finding the next trade.',
        ],
      ),
      Lesson(
        id: 'rm_3',
        title: 'Bankroll Management',
        subtitle: 'Think long-term across matches',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Your Platform Balance',
            body:
                'Beyond individual trades, think about your total platform balance across all matches. Available bet amounts are \$5, \$10, \$50, \$100, and \$1,000. Don\'t bet your entire balance on a single match. If you have \$200, play \$5-\$10 matches to give yourself 20-40 opportunities. Even the best traders lose sometimes — bankroll management ensures you survive the losing streaks.',
          ),
          LessonSection(
            heading: 'Moving Up in Stakes',
            body:
                'Only move to higher bet amounts when your win rate proves you\'re profitable. A rough guide:\n- Start at \$5 matches to learn the ropes.\n- After 10+ matches with a positive win rate, consider moving to \$10.\n- After consistent success at \$10, try \$50.\n- After a losing streak (3+ losses), drop back down immediately.\n\nCheck your Portfolio page to review your match history, win rate, and total P&L before moving up.',
          ),
          LessonSection(
            heading: 'Tilt Control',
            body:
                'After a loss, you\'ll feel the urge to immediately queue again with a bigger bet to "win it back." This is tilt — emotional decision-making. It almost always leads to bigger losses. After a loss, take a 5-minute break. Review what went wrong in your match history. Then decide calmly whether to play again. Your win streak stat on the leaderboard resets on a loss — don\'t let tilt destroy a long streak.',
          ),
        ],
        keyTakeaways: [
          'Never bet more than 25% of your platform balance on one match.',
          'Start small at \$5 and move up only after proven profitability.',
          'Drop down in stakes after losing streaks — preserve your bankroll.',
          'Recognize tilt — take breaks after losses and review your match history.',
        ],
      ),
      Lesson(
        id: 'rm_4',
        title: 'Psychology of Trading',
        subtitle: 'Your biggest opponent is yourself',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Fear and Greed',
            body:
                'Fear makes you close winning trades too early and hesitate on good setups. Greed makes you hold losing trades too long and over-leverage. Recognizing these emotions in real-time is a skill that separates winning traders from losing ones. Before every trade, ask: "Am I making this decision based on analysis or emotion?"',
          ),
          LessonSection(
            heading: 'The Plan Before the Match',
            body:
                'Enter every match with a plan: What\'s the current trend? Which assets look strongest? What leverage will I use? What\'s my max position size? Having a plan prevents impulsive decisions. Use the match phases as structure — Opening Bell for assessment, Mid Game for execution, Final Sprint for risk management, Last Stand for protecting or clawing back.',
          ),
          LessonSection(
            heading: 'Accepting Losses',
            body:
                'Losses are part of trading. Even the best SolFight players lose 30-40% of their matches. What makes them profitable is that their wins are bigger than their losses — thanks to the 90% payout on wins and disciplined risk management. Accept that some matches are unwinnable — the market moved against you, the opponent was better, or your read was wrong. Review your stats on the leaderboard and Portfolio page, learn from mistakes, and move on.',
          ),
        ],
        keyTakeaways: [
          'Emotion is the enemy — trade based on analysis, not feelings.',
          'Use match phases as structure: assess, execute, manage, protect.',
          'Losing is normal — focus on making wins bigger than losses.',
          'Review every match on your Portfolio page to improve over time.',
        ],
      ),
    ],
  ),

  // ── Path 5: Advanced Tactics ───────────────────────────────────────────────
  LearningPath(
    id: 'advanced',
    title: 'Advanced Tactics',
    description: 'Pro-level strategies to dominate the Arena.',
    icon: Icons.emoji_events_rounded,
    color: AppTheme.solanaPurple,
    tag: 'ADVANCED',
    lessons: [
      Lesson(
        id: 'ad_1',
        title: 'Reading Your Opponent',
        subtitle: 'Use the Arena HUD to your advantage',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Opponent ROI Tracking',
            body:
                'The Arena HUD shows your opponent\'s ROI in real-time, updated every 3 seconds. If they\'re up big, they might become conservative — protecting their lead with smaller positions or closing trades. If they\'re down, they might take aggressive risks with higher leverage. Use this information to adjust your strategy: when you\'re ahead, play defense; when you\'re behind, find high-conviction setups.',
          ),
          LessonSection(
            heading: 'Position Count Signals',
            body:
                'The HUD also shows how many open positions your opponent has. If they have 0, they might be waiting for a setup or protecting a lead in cash. If they have multiple positions, they\'re actively trading and spreading risk. A sudden increase in positions might signal a desperate catch-up attempt. The Events Feed also notifies you of opponent trades, lead changes, and liquidations.',
          ),
          LessonSection(
            heading: 'The Battle Bar & Events',
            body:
                'The Battle Bar is a tug-of-war indicator showing who\'s winning. Watch it shift — sudden swings mean your opponent made a big move. The Events Feed alerts you to lead changes, big P&L swings, streaks, and phase transitions. Use this information to stay one step ahead. If you see "Lead Change!" in the feed, reassess your positions immediately.',
          ),
          LessonSection(
            heading: 'Chat Strategy',
            body:
                'The in-match chat lets you communicate with your opponent. Some players try to psych you out or distract you. Stay focused on your charts and strategy. A confident "GL" at the start can set the tone, but don\'t let trash talk affect your decisions. The best use of chat is to tilt your opponent when you\'re winning — but never let it tilt you.',
          ),
        ],
        keyTakeaways: [
          'Opponent ROI and position count update every 3 seconds — watch them.',
          'The Battle Bar and Events Feed reveal opponent moves in real-time.',
          'When ahead: play defensive. When behind: take calculated risks.',
          'Don\'t let chat distract you — stay focused on the charts.',
        ],
      ),
      Lesson(
        id: 'ad_2',
        title: 'Multi-Asset Rotation',
        subtitle: 'Trade the strongest mover',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Asset Correlation',
            body:
                'BTC, ETH, and SOL are correlated but not identical. BTC leads the market — when BTC makes a big move, ETH and SOL usually follow. However, SOL is more volatile and often moves more in percentage terms. ETH sits in the middle. Understanding these relationships helps you choose which asset to trade at any moment. The asset bar lets you switch instantly.',
          ),
          LessonSection(
            heading: 'Rotation Strategy',
            body:
                'During a match, don\'t commit to one asset. Start by watching all three. If BTC breaks out of a range, SOL will likely follow with a bigger move — open your position on SOL for amplified returns. If the market is choppy, look for the one asset showing the clearest trend and focus there. The Quick Trade Grid defaults reflect typical volatility: BTC 10x, ETH 25x, SOL 50x.',
          ),
          LessonSection(
            heading: 'Hedging Across Assets',
            body:
                'In longer matches, you can hedge by going long on one asset and short on another. If BTC is showing strength relative to SOL, go long BTC and short SOL. This way, even in a market-wide dump, your BTC position loses less than your SOL short gains. This advanced technique reduces directional risk and can give you steady ROI regardless of market direction.',
          ),
        ],
        keyTakeaways: [
          'SOL is most volatile, BTC is most stable, ETH is in between.',
          'When BTC leads, SOL follows with bigger moves — trade the amplifier.',
          'Focus on the asset with the clearest signal at any given moment.',
          'Hedging (long one asset, short another) reduces directional risk.',
        ],
      ),
      Lesson(
        id: 'ad_3',
        title: 'Mean Reversion',
        subtitle: 'Profit from overreactions',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'The Core Idea',
            body:
                'Mean reversion is the tendency of price to return to its average after an extreme move. When price spikes too far too fast (overbought), it often pulls back. When it dumps too hard (oversold), it often bounces. This strategy profits from these corrections — you\'re betting that extremes don\'t last.',
          ),
          LessonSection(
            heading: 'Identifying Extremes',
            body:
                'Look for: Sudden large candles with long wicks (overextension). Price far from recent averages. Multiple consecutive candles in one direction (exhaustion). In a 15m match, even a 0.5% spike can be an overreaction in crypto. Enter a counter-trade with tight stops above the extreme.',
          ),
          LessonSection(
            heading: 'When NOT to Mean-Revert',
            body:
                'Don\'t fade a strong trend just because it "looks overextended." If BTC is breaking out above major resistance on a massive candle, that\'s likely a real move, not an overreaction. Mean reversion works best in ranging markets or during low-volume spikes. In strong trends, trade WITH the momentum instead. Check the Events Feed — if your opponent just got liquidated on a trend trade, the trend is probably real.',
          ),
        ],
        keyTakeaways: [
          'Mean reversion = bet that overreactions will correct.',
          'Works best in ranging, choppy markets.',
          'Don\'t fight strong trends with real conviction behind them.',
          'Use tight stops when mean-reverting — you\'re trading against momentum.',
        ],
      ),
      Lesson(
        id: 'ad_4',
        title: 'Match Endgame Tactics',
        subtitle: 'Win the final minutes',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'Understanding Match Phases',
            body:
                'Every SolFight match progresses through five phases:\n\n• Opening Bell (first 20%): Feel out the market, make initial assessments.\n• Mid Game (20-70%): Execute your core strategy.\n• Final Sprint (70-90%): Urgency increases — the Arena turns amber. Time to lock in gains or make your move.\n• Last Stand (final 10%): Maximum intensity — the Arena turns red. This is where matches are decided.\n• Match End: All positions auto-close at current market prices and ROI is compared.\n\nPhase banners slide down to announce each transition. Adapt your strategy to each phase.',
          ),
          LessonSection(
            heading: 'Managing a Lead',
            body:
                'If you\'re ahead entering Final Sprint, your goal shifts from making money to protecting your lead. Close risky positions. Reduce leverage on remaining trades. Move to cash if your lead is comfortable. Your opponent will be forced to take big risks during Last Stand — let them make mistakes while you play it safe. Watch the Battle Bar; if it stays in your favor, you\'re doing it right.',
          ),
          LessonSection(
            heading: 'Comeback Strategy',
            body:
                'If you\'re behind with the match in Final Sprint or Last Stand, you need to take bigger swings. Increase leverage slightly, look for the highest-conviction setup across all three assets, and go for it. SOL\'s higher volatility makes it the best asset for comebacks. But don\'t blindly max leverage on a coin flip — even when behind, identify a real setup. One well-timed trade with 25-50x leverage can close a big gap quickly.',
          ),
          LessonSection(
            heading: 'The Final Moments',
            body:
                'In the last minute, all positions auto-close when the match timer hits zero. If you\'re ahead, consider closing all positions manually to lock in your exact P&L — a sudden price swing before auto-close could hurt you. If you\'re behind, keep your positions open — you need the volatility. Also know: if your opponent disconnects during the match, there\'s a 30-second grace period. If they don\'t reconnect, you win by forfeit.',
          ),
        ],
        keyTakeaways: [
          'Match phases: Opening Bell → Mid Game → Final Sprint → Last Stand → End.',
          'When ahead in Final Sprint: reduce risk, protect the lead.',
          'When behind in Last Stand: find one high-conviction setup on SOL.',
          'Consider manual closes before auto-close if you\'re protecting a lead.',
        ],
      ),
    ],
  ),

  // ── Path 6: Platform Features ──────────────────────────────────────────────
  LearningPath(
    id: 'platform_features',
    title: 'Platform Features',
    description: 'Master deposits, clans, leaderboards, and referrals.',
    icon: Icons.apps_rounded,
    color: AppTheme.solanaGreen,
    tag: 'PLATFORM',
    lessons: [
      Lesson(
        id: 'pf_1',
        title: 'Deposits & Withdrawals',
        subtitle: 'Manage your USDC on the platform',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'How Platform Balance Works',
            body:
                'SolFight uses a platform balance system so gameplay is instant — no waiting for blockchain confirmations during matches. Your on-chain USDC lives in your wallet. When you deposit, it transfers to the platform vault and credits your platform balance. When you bet on a match, the amount is "frozen" from your available balance. When the match ends, winnings are credited or losses deducted instantly.',
          ),
          LessonSection(
            heading: 'Making a Deposit',
            body:
                'Go to your Portfolio page and click "Deposit." You\'ll send USDC to the SolFight platform vault address on Solana. After the transaction confirms, the backend verifies it on-chain — checking the signature, sender, receiver, and amount — then credits your platform balance. Each deposit signature can only be used once (replay protection). Deposits must confirm within 5 minutes.',
          ),
          LessonSection(
            heading: 'Withdrawing Funds',
            body:
                'To withdraw, click "Withdraw" on your Portfolio page and enter the amount (minimum \$1). The backend deducts from your platform balance and sends USDC on-chain to your wallet. If you don\'t have an Associated Token Account (ATA) for USDC, it\'s created automatically. Withdrawals process immediately — you\'ll see the USDC back in your wallet within seconds.',
          ),
          LessonSection(
            heading: 'Balance Breakdown',
            body:
                'Your Portfolio page shows four balance components:\n\n• On-Chain Balance: USDC in your connected wallet.\n• Platform Balance: Total USDC held on the platform.\n• Frozen Balance: Amount locked in active matches (returned when the match ends).\n• Available Balance: Platform balance minus frozen — this is what you can bet or withdraw.',
          ),
        ],
        keyTakeaways: [
          'Platform balance enables instant gameplay — no blockchain delays.',
          'Deposits are verified on-chain with replay protection.',
          'Withdrawals process immediately back to your wallet.',
          'Available balance = Platform balance - Frozen balance.',
        ],
      ),
      Lesson(
        id: 'pf_2',
        title: 'Leaderboard & Rankings',
        subtitle: 'Track your rank and compete for the top',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'How Rankings Work',
            body:
                'The SolFight leaderboard ranks players by wins, P&L, or current streak. Your stats update in real-time after every match. The top 3 players get a podium display with special styling, while 4th place and below appear in the rankings table. Your row is highlighted if you\'re on the board.',
          ),
          LessonSection(
            heading: 'Leaderboard Filters',
            body:
                'You can filter the leaderboard by:\n\n• Time Period: Weekly, Monthly, or All Time.\n• Match Duration: All, 5m, 15m, 1h, 4h, or 24h.\n\nThis lets you find the best players in your preferred match type. A player who dominates 15m scalping matches might not appear on the 24h leaderboard, and vice versa.',
          ),
          LessonSection(
            heading: 'Stats Tracked',
            body:
                'The leaderboard displays: Rank, Gamer Tag, Wins, Win Rate %, Games Played, Total P&L, and Current Streak. Your match history on the Portfolio page tracks even more detail: each match result with opponent name, P&L, duration, and timestamp.',
          ),
        ],
        keyTakeaways: [
          'Leaderboard ranks by wins, P&L, or streak with real-time updates.',
          'Filter by time period (Weekly/Monthly/All Time) and match duration.',
          'Top 3 get a podium display — aim for the top.',
          'Your Portfolio page has detailed match-by-match history.',
        ],
      ),
      Lesson(
        id: 'pf_3',
        title: 'Clans & Community',
        subtitle: 'Join forces with other traders',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'What Are Clans?',
            body:
                'Clans are groups of up to 50 SolFight players who team up. Each clan has a name, a short tag (3-5 characters), a description, and a leader. Clans track collective stats including total wins, losses, win rate, trophies, and level. It\'s a way to build community, share strategies, and compete with other groups.',
          ),
          LessonSection(
            heading: 'Creating or Joining a Clan',
            body:
                'To create a clan, go to the Clans tab and tap "Create." Choose a name (up to 30 characters), a tag (up to 5 characters, displayed in uppercase), and an optional description. You\'ll automatically be set as the Leader.\n\nTo join an existing clan, browse the clan directory (sorted by trophies) or search by name. Tap a clan to see its members, stats, and war history, then tap "Join." You can only be in one clan at a time.',
          ),
          LessonSection(
            heading: 'Clan Roles & Management',
            body:
                'Clans have four roles: Leader, Co-Leader, Elder, and Member. The Leader manages the clan. If the Leader leaves, leadership transfers to the next member. If all members leave, the clan is dissolved. Each member\'s profile shows their trophies, donations, and join date within the clan.',
          ),
        ],
        keyTakeaways: [
          'Clans hold up to 50 members with tracked collective stats.',
          'Create a clan with a name and tag, or browse and join existing ones.',
          'Four roles: Leader, Co-Leader, Elder, Member.',
          'You can only be in one clan at a time.',
        ],
      ),
      Lesson(
        id: 'pf_4',
        title: 'Referrals & Rewards',
        subtitle: 'Earn by inviting friends',
        readMinutes: 2,
        sections: [
          LessonSection(
            heading: 'Your Referral Code',
            body:
                'Every SolFight player gets a unique referral code generated from their wallet address. Find it on the Referral page along with a shareable link and a QR code. Share it with friends via direct link, QR code, or social media.',
          ),
          LessonSection(
            heading: 'How Referrals Work',
            body:
                'When someone uses your referral code and joins SolFight, they\'re linked to your account. The Referral page tracks each referred user with their gamer tag, status (joined, deposited, or played their first match), join date, and any reward earned. Rewards are auto-credited to your platform balance when referred users hit milestones.',
          ),
          LessonSection(
            heading: 'Tracking Your Rewards',
            body:
                'The Referral page shows your total earnings from referrals, pending rewards, and a full list of everyone you\'ve referred. Growing your referral network is a great way to earn extra USDC while bringing more opponents into the arena.',
          ),
        ],
        keyTakeaways: [
          'Every player gets a unique referral code, link, and QR code.',
          'Referred users are tracked through milestones: joined, deposited, played.',
          'Rewards are auto-credited to your platform balance.',
          'More referrals = more earnings and a larger player pool.',
        ],
      ),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// Trading Glossary
// ═══════════════════════════════════════════════════════════════════════════════

const allGlossaryTerms = <GlossaryTerm>[
  GlossaryTerm(term: 'Long', definition: 'A position that profits when price goes up.'),
  GlossaryTerm(term: 'Short', definition: 'A position that profits when price goes down.'),
  GlossaryTerm(term: 'Leverage', definition: 'Multiplier that amplifies your position size relative to your margin. 10x leverage = 10x gains/losses. SolFight offers 1x to 100x.'),
  GlossaryTerm(term: 'Liquidation', definition: 'Forced closure of your position when losses consume 90% of your margin. Higher leverage = smaller price move needed to trigger it.'),
  GlossaryTerm(term: 'Stop Loss (SL)', definition: 'An order that automatically closes your position at a set loss level. Monitored every second by the backend.'),
  GlossaryTerm(term: 'Take Profit (TP)', definition: 'An order that automatically closes your position at a set profit level. Monitored every second by the backend.'),
  GlossaryTerm(term: 'PnL', definition: 'Profit and Loss — the dollar gain/loss on a position or across all positions in a match.'),
  GlossaryTerm(term: 'ROI', definition: 'Return on Investment — your percentage gain/loss relative to the \$1M demo balance. The player with higher ROI wins the match.'),
  GlossaryTerm(term: 'Equity', definition: 'Your total account value including unrealized profits/losses from open positions.'),
  GlossaryTerm(term: 'Demo Balance', definition: 'The \$1,000,000 starting balance each player receives at the start of every match for trading.'),
  GlossaryTerm(term: 'Platform Balance', definition: 'Your USDC held on the SolFight platform, used for bets and winnings. Separate from your on-chain wallet balance.'),
  GlossaryTerm(term: 'Frozen Balance', definition: 'Portion of your platform balance locked in active matches. Released when the match ends.'),
  GlossaryTerm(term: 'Rake', definition: 'The 10% fee taken from the winner\'s payout by the SolFight protocol. Loser forfeits their full bet.'),
  GlossaryTerm(term: 'Candlestick', definition: 'A chart element showing open, close, high, and low prices for a time period.'),
  GlossaryTerm(term: 'Support', definition: 'A price level where buying pressure prevents further decline.'),
  GlossaryTerm(term: 'Resistance', definition: 'A price level where selling pressure prevents further increase.'),
  GlossaryTerm(term: 'Breakout', definition: 'When price moves above resistance or below support with conviction.'),
  GlossaryTerm(term: 'Scalping', definition: 'Making many small, quick trades to capture tiny price movements.'),
  GlossaryTerm(term: 'Swing Trading', definition: 'Holding positions longer to capture larger price moves.'),
  GlossaryTerm(term: 'Mean Reversion', definition: 'A strategy that bets on price returning to its average after an extreme move.'),
  GlossaryTerm(term: 'Doji', definition: 'A candlestick with nearly equal open and close, signaling market indecision.'),
  GlossaryTerm(term: 'Engulfing', definition: 'A large candle that completely covers the previous candle — signals reversal.'),
  GlossaryTerm(term: 'Quick Trade Grid', definition: 'Six preset buttons in the Arena for instant trades: Long/Short BTC 10x, ETH 25x, SOL 50x.'),
  GlossaryTerm(term: 'Battle Bar', definition: 'A tug-of-war indicator in the Arena HUD showing who is currently winning the match.'),
  GlossaryTerm(term: 'Match Phase', definition: 'Timed stages of a match: Opening Bell, Mid Game, Final Sprint (amber), Last Stand (red), and Match End.'),
  GlossaryTerm(term: 'Forfeit', definition: 'When a player disconnects for more than 30 seconds, the match is awarded to the remaining player.'),
  GlossaryTerm(term: 'Clan', definition: 'A group of up to 50 SolFight players with shared stats, trophies, and community features.'),
  GlossaryTerm(term: 'Gamer Tag', definition: 'Your display name on SolFight (1-16 characters), visible to opponents and on leaderboards.'),
  GlossaryTerm(term: 'Tilt', definition: 'Emotional state after a loss that leads to impulsive, often poor decisions. Take a break when tilted.'),
  GlossaryTerm(term: 'USDC', definition: 'A stablecoin pegged to the US Dollar, used for bets and winnings on SolFight.'),
  GlossaryTerm(term: 'Devnet', definition: 'Solana\'s test network where SolFight currently runs. All tokens are free — no real money at risk.'),
  GlossaryTerm(term: 'Reward-to-Risk Ratio', definition: 'How much you stand to gain vs how much you risk. 2:1 means targeting \$2 profit for every \$1 risked.'),
  GlossaryTerm(term: 'Referral Code', definition: 'A unique code tied to your wallet address that earns you rewards when friends join SolFight.'),
  GlossaryTerm(term: 'Notional Size', definition: 'The total value of your leveraged position. A \$10,000 margin at 10x leverage = \$100,000 notional size.'),
];
