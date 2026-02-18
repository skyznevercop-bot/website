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
                'SolFight is a player-vs-player trading arena built on Solana. Instead of trading against the market alone, you compete head-to-head against another trader. Both players start with the same virtual balance and trade the same assets (BTC, ETH, SOL) over a fixed timeframe. The player with the higher portfolio ROI at the end wins the match and takes the prize pool.',
          ),
          LessonSection(
            heading: 'How Matches Work',
            body:
                'You choose a timeframe (15 minutes to 24 hours) and a bet amount in USDC. The system matches you with an opponent who chose the same timeframe and bet. Once matched, you both enter the Arena — a real-time trading interface with live price feeds, charting tools, and a chat window. You can go long or short on BTC, ETH, or SOL with up to 50x leverage.',
          ),
          LessonSection(
            heading: 'The Prize Pool',
            body:
                'Both players deposit their bet amount into a Solana escrow smart contract before the match starts. The winner receives 90% of the total pool (their own bet + 90% of the opponent\'s bet). The remaining 10% goes to the SolFight protocol. For example, in a \$25 match, the winner walks away with \$47.50.',
          ),
          LessonSection(
            heading: 'Why SolFight?',
            body:
                'Traditional trading can feel isolating. SolFight adds a competitive layer — you\'re not just trying to make money, you\'re trying to outperform a real human opponent under the same market conditions. It\'s like chess, but with candlestick charts. Your skill, strategy, and risk management directly determine the outcome.',
          ),
        ],
        keyTakeaways: [
          'SolFight is PvP trading — you compete against another human, not the house.',
          'Both players trade the same assets with the same starting balance.',
          'Winner takes 90% of the combined prize pool.',
          'Matches range from 15 minutes to 24 hours.',
        ],
      ),
      Lesson(
        id: 'gs_2',
        title: 'Connecting Your Wallet',
        subtitle: 'Set up Phantom or Solflare in 2 minutes',
        readMinutes: 2,
        sections: [
          LessonSection(
            heading: 'Supported Wallets',
            body:
                'SolFight supports Phantom, Solflare, Backpack, and any Solana-compatible browser wallet. Phantom is the most popular choice and works as a Chrome extension or mobile app. You\'ll need your wallet to sign transactions, deposit USDC into escrow, and receive winnings.',
          ),
          LessonSection(
            heading: 'Connecting Step-by-Step',
            body:
                '1. Click the "Connect Wallet" button in the top bar.\n2. Choose your wallet provider from the modal.\n3. Approve the connection request in your wallet extension.\n4. Your wallet address and USDC balance will appear in the top bar.\n\nThat\'s it — you\'re now authenticated and ready to queue for matches.',
          ),
          LessonSection(
            heading: 'Getting Devnet USDC',
            body:
                'SolFight currently runs on Solana Devnet, so you need Devnet USDC (not real money). You can get free Devnet SOL from a faucet like faucet.solana.com, then swap it for Devnet USDC using the platform\'s built-in deposit flow. This lets you practice and compete without risking real funds.',
          ),
        ],
        keyTakeaways: [
          'Phantom is the recommended wallet for beginners.',
          'Connecting takes ~30 seconds — just approve the popup.',
          'We\'re on Devnet, so all funds are free test tokens.',
        ],
      ),
      Lesson(
        id: 'gs_3',
        title: 'Your First Match',
        subtitle: 'Join a queue and enter the Arena',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Choosing a Timeframe',
            body:
                'On the Play screen, you\'ll see five timeframe options: 15 minutes, 1 hour, 4 hours, 12 hours, and 24 hours. Shorter timeframes are more action-packed and require quick decisions. Longer timeframes let you ride trends and think more strategically. Start with 15-minute or 1-hour matches to learn the ropes.',
          ),
          LessonSection(
            heading: 'Joining the Queue',
            body:
                'Select your timeframe, choose a bet amount, and click "Join Queue." The matchmaking system will pair you with an opponent who selected the same timeframe and bet. Queue times depend on how many players are active — popular timeframes like 15m and 1h usually match within seconds.',
          ),
          LessonSection(
            heading: 'The Opponent Found Screen',
            body:
                'When an opponent is found, you\'ll see their gamer tag and a countdown to deposit your bet into the Solana escrow. Approve the transaction in your wallet — once both players deposit, the match begins immediately and you\'re taken to the Arena.',
          ),
          LessonSection(
            heading: 'Arena Basics',
            body:
                'The Arena shows a live price chart, your portfolio (balance + open positions), and your opponent\'s ROI. Use the order panel on the right to open long or short positions. You can set leverage, stop-loss, and take-profit levels. At the end of the timeframe, all positions auto-close and the player with the higher ROI wins.',
          ),
        ],
        keyTakeaways: [
          'Start with 15m or 1h matches to learn quickly.',
          'Queue times are shortest during peak hours.',
          'Both players must deposit before the match starts.',
          'The Arena auto-closes all positions when time runs out.',
        ],
      ),
      Lesson(
        id: 'gs_4',
        title: 'Understanding the Arena UI',
        subtitle: 'Navigate charts, orders, and positions',
        readMinutes: 4,
        sections: [
          LessonSection(
            heading: 'The Price Chart',
            body:
                'The center of the Arena is a real-time candlestick chart showing the selected asset\'s price. You can switch between BTC, ETH, and SOL using the asset tabs above the chart. The chart updates every second with live market data. Use it to identify trends, support/resistance levels, and entry points.',
          ),
          LessonSection(
            heading: 'The Order Panel',
            body:
                'On the right side (or in the "Trade" tab on mobile), you\'ll find the order panel. Here you can:\n- Choose Long (bet price goes up) or Short (bet price goes down)\n- Set your position size using percentage buttons (25%, 50%, 75%, MAX)\n- Choose leverage (1x to 50x)\n- Set optional Stop Loss and Take Profit prices\n- Click "Open Long" or "Open Short" to execute',
          ),
          LessonSection(
            heading: 'Open Positions & Closed Trades',
            body:
                'Below the chart (desktop) or in the "Positions" tab (mobile), you can see your open positions with live P&L, and your closed trades history. Each position shows the asset, direction, entry price, size, leverage, and current unrealized P&L. You can manually close any position at any time by clicking the X button.',
          ),
          LessonSection(
            heading: 'The Toolbar',
            body:
                'The Arena toolbar at the top shows:\n- Match timer (countdown to match end)\n- Your opponent\'s gamer tag and ROI\n- Your portfolio balance and equity\n- A chat button (desktop) to message your opponent\n\nKeep an eye on the timer — when it hits zero, all positions auto-close and the winner is decided.',
          ),
        ],
        keyTakeaways: [
          'Switch between BTC, ETH, SOL using the asset tabs.',
          'Use percentage buttons for quick position sizing.',
          'Monitor both your P&L and your opponent\'s ROI in the toolbar.',
          'Positions auto-close when the match timer reaches zero.',
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
                'A candlestick represents price movement over a specific time period. Each candle has four data points: Open (where the price started), Close (where it ended), High (the highest price reached), and Low (the lowest). A green candle means the price closed higher than it opened (bullish). A red candle means it closed lower (bearish).',
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
                'In a 15-minute match, each 1-minute candle matters. Look for reversal patterns near support or resistance to time your entries. In longer matches (4h+), zoom out and use hourly candles to identify the broader trend before zooming in for precise entries.',
          ),
        ],
        keyTakeaways: [
          'Green = bullish (price went up), Red = bearish (price went down).',
          'Long wicks show price rejection — important reversal signals.',
          'Learn to spot Doji, Hammer, and Engulfing patterns.',
          'Match your candle timeframe to your match duration.',
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
                'When price finally breaks through support or resistance with strong volume, it\'s called a breakout (up through resistance) or breakdown (down through support). These are powerful trading signals. The old resistance often becomes new support after a breakout, and vice versa. This "flip" is one of the most reliable patterns in trading.',
          ),
          LessonSection(
            heading: 'Applying to SolFight Matches',
            body:
                'Before opening any position, identify the nearest support and resistance levels on the chart. Go long near support (with a stop loss just below). Go short near resistance (with a stop loss just above). If you see a breakout, ride the momentum. These levels give you an edge by defining clear entry, exit, and risk points.',
          ),
        ],
        keyTakeaways: [
          'Support = floor (price bounces up), Resistance = ceiling (price bounces down).',
          'The more times a level holds, the stronger it is.',
          'Broken resistance becomes new support (and vice versa).',
          'Always trade with nearby support/resistance in mind.',
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
                'Before a match starts, quickly assess the current trend on the 1-hour and 15-minute charts. If there\'s a clear uptrend, lean towards long positions. If it\'s a downtrend, lean short. If it\'s ranging, play the bounces between support and resistance. Having a directional bias from the start gives you a plan instead of random trades.',
          ),
        ],
        keyTakeaways: [
          'Uptrend: higher highs + higher lows. Favor longs.',
          'Downtrend: lower highs + lower lows. Favor shorts.',
          'Range: play the bounces or wait for breakout.',
          'Identify the trend BEFORE the match starts.',
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
            heading: 'Momentum Indicators',
            body:
                'RSI (Relative Strength Index) measures how fast price is moving. Above 70 = overbought (may reverse down). Below 30 = oversold (may reverse up). MACD shows momentum direction changes — when the MACD line crosses above the signal line, it\'s bullish. These indicators won\'t be on the SolFight chart by default, but understanding their logic helps you read raw price action.',
          ),
        ],
        keyTakeaways: [
          'High volume confirms price moves; low volume signals caution.',
          'Price + falling volume = weakening trend (divergence).',
          'RSI above 70 = overbought, below 30 = oversold.',
          'Use momentum concepts even without explicit indicators.',
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
                'When you go long, you profit when the price goes up. You buy at a lower price and aim to sell higher. In SolFight, opening a long position is a bet that the asset\'s price will increase during the match. Example: BTC is at \$60,000, you go long with 10x leverage and \$100 size. If BTC rises 1%, your position gains \$100 (10x your collateral\'s 1% move = 10% return).',
          ),
          LessonSection(
            heading: 'Going Short',
            body:
                'When you go short, you profit when the price drops. You\'re essentially selling first and buying back later at a lower price. In SolFight, shorting is a bet that the asset will decline. Example: ETH is at \$3,000, you short with 5x leverage and \$200 size. If ETH drops 2%, your position gains \$200 (5x * 2% = 10% return on your collateral).',
          ),
          LessonSection(
            heading: 'When to Long vs Short',
            body:
                'Long when: the trend is bullish, price just bounced off support, or you see bullish reversal candles. Short when: the trend is bearish, price just hit resistance, or bearish candles form. In SolFight, being able to profit in both directions is your biggest advantage — you\'re never stuck waiting for the market to go one way.',
          ),
        ],
        keyTakeaways: [
          'Long = profit when price goes up. Short = profit when price goes down.',
          'Leverage amplifies both gains AND losses.',
          'Always trade in the direction of the trend when possible.',
          'Being able to short is a massive advantage over buy-and-hold investors.',
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
                'Use higher leverage (10-25x) with small position sizes so a quick 0.1-0.3% move gives meaningful profit. Set tight stop losses (cut losers fast) and take profits quickly. Watch the 1-minute candles closely. Enter on bounces at micro-support levels or on small breakouts.',
          ),
          LessonSection(
            heading: 'Scalping in 15m Matches',
            body:
                'In a 15-minute SolFight match, scalping is the dominant strategy. You don\'t have time for big trends to develop — you need quick wins. Open a position, set a tight TP, close it within 1-2 minutes, then look for the next trade. The player who makes more correct micro-decisions wins.',
          ),
          LessonSection(
            heading: 'Common Mistakes',
            body:
                'Don\'t overtrade — if you\'re not seeing clear setups, wait. Don\'t use MAX leverage with your full balance — one bad trade wipes you out. Don\'t hold a losing scalp hoping it will recover — close it and find a new entry. Speed is important, but discipline is more important.',
          ),
        ],
        keyTakeaways: [
          'Scalping = many small, fast trades with leverage.',
          'Best for 15m and 1h matches.',
          'Cut losses fast, take profits quickly.',
          'Discipline > speed. Don\'t overtrade.',
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
                'Swing trading means holding positions for a longer period to capture larger price moves. In SolFight, this applies to 4h, 12h, and 24h matches. Instead of making 10 small trades, you might make 1-3 well-chosen positions and let them ride. The goal is to identify the dominant trend and position yourself early.',
          ),
          LessonSection(
            heading: 'Swing Setup',
            body:
                'Use moderate leverage (2-10x) with larger position sizes. Identify the trend on the hourly chart, then wait for a pullback to enter. Set wider stop losses (give the trade room to breathe) and wider take profits (capture the full move). Patience is key — don\'t panic-close on small pullbacks.',
          ),
          LessonSection(
            heading: 'Multi-Asset Diversification',
            body:
                'In longer matches, consider splitting your balance across BTC, ETH, and SOL. If BTC is trending up and SOL is ranging, go long BTC and play SOL\'s range. This reduces your dependency on a single asset and smooths out your P&L.',
          ),
        ],
        keyTakeaways: [
          'Swing trading = fewer trades, bigger moves, more patience.',
          'Best for 4h, 12h, and 24h matches.',
          'Use moderate leverage and wider stops.',
          'Consider diversifying across multiple assets.',
        ],
      ),
      Lesson(
        id: 'st_4',
        title: 'Using Leverage Wisely',
        subtitle: 'Amplify without destroying',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'What Leverage Does',
            body:
                'Leverage multiplies your position size relative to your collateral. With 10x leverage, a \$100 position controls \$1,000 worth of the asset. A 1% price move becomes a 10% gain or loss on your collateral. SolFight offers 1x to 50x leverage.',
          ),
          LessonSection(
            heading: 'The Liquidation Trap',
            body:
                'Higher leverage means a smaller price move can liquidate you (lose your entire position). At 50x leverage, a mere 2% adverse move wipes out your position. At 10x, it takes 10%. At 2x, it takes 50%. Many beginners max out leverage and get liquidated on normal market noise. Don\'t be that person.',
          ),
          LessonSection(
            heading: 'Recommended Leverage by Match Type',
            body:
                '15-minute matches: 10-25x (price won\'t move much, you need leverage to generate returns)\n1-hour matches: 5-15x (moderate volatility)\n4+ hour matches: 2-10x (longer time = bigger moves = lower leverage needed)\n\nA useful rule: the longer the match, the lower the leverage. Let time create the returns instead of leverage.',
          ),
        ],
        keyTakeaways: [
          'Leverage amplifies BOTH gains and losses.',
          'Higher leverage = closer liquidation price.',
          'Short matches: higher leverage. Long matches: lower leverage.',
          'Never go 50x with your full balance — leave room for error.',
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
                'Never risk more than 20-30% of your match balance on a single trade. If you put 100% into one position and it goes wrong, the match is over. By keeping individual positions small, you can take multiple shots at winning. Even if 2 out of 5 trades fail, the remaining 3 can carry you to victory.',
          ),
          LessonSection(
            heading: 'The 25/50/75/MAX Buttons',
            body:
                'The Arena has quick buttons: 25%, 50%, 75%, and MAX. For most situations, 25% is the safest starting size. 50% is aggressive but acceptable. 75% and MAX should only be used when you have extremely high conviction — like a clear breakout with volume confirmation. Start small, scale up as you gain confidence.',
          ),
          LessonSection(
            heading: 'Splitting Across Assets',
            body:
                'Instead of one 50% position on BTC, consider two 25% positions on BTC and ETH. If both assets are trending the same way, you benefit from both. If one underperforms, the other might compensate. Diversification within a match reduces the impact of any single bad trade.',
          ),
        ],
        keyTakeaways: [
          'Never risk more than 20-30% per trade.',
          'Start with the 25% button and scale up with conviction.',
          'Spread across assets to reduce single-trade risk.',
          'Surviving to make more trades is more important than one big win.',
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
                'A stop loss automatically closes your position if the price moves against you by a set amount. Without one, a small loss can snowball into a liquidation. Setting a stop loss is the single most important risk management tool. It removes emotion from the equation — the system exits for you when the trade is wrong.',
          ),
          LessonSection(
            heading: 'Setting Effective Stop Losses',
            body:
                'Place your stop loss below the nearest support (for longs) or above the nearest resistance (for shorts). Don\'t set it too tight (you\'ll get stopped out by normal noise) or too wide (you\'ll lose too much before it triggers). A good rule: your stop should be at a level where, if hit, your trade thesis is clearly wrong.',
          ),
          LessonSection(
            heading: 'Take Profit Targets',
            body:
                'A take profit automatically closes your position when it reaches a target gain. Aim for a reward-to-risk ratio of at least 2:1. If your stop loss risks \$50, your take profit should target at least \$100. This way, you only need to be right 40% of the time to be profitable overall.',
          ),
        ],
        keyTakeaways: [
          'Always set a stop loss — no exceptions.',
          'Place stops below support (longs) or above resistance (shorts).',
          'Aim for 2:1 or better reward-to-risk ratio.',
          'Take profits let you lock in gains without watching the screen.',
        ],
      ),
      Lesson(
        id: 'rm_3',
        title: 'Bankroll Management',
        subtitle: 'Think long-term across matches',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Your Overall Balance',
            body:
                'Beyond individual trades, think about your total USDC balance across all matches. Don\'t bet your entire balance on a single match. If you have \$100, consider playing \$10-\$25 matches. This gives you 4-10 opportunities to win. Even the best traders lose sometimes — bankroll management ensures you survive the losing streaks.',
          ),
          LessonSection(
            heading: 'Moving Up in Stakes',
            body:
                'Only move to higher bet amounts when your win rate consistently proves you\'re profitable. A rough guide:\n- Start at the lowest bet amount available.\n- After 10+ matches with a positive win rate, consider moving up one level.\n- After a losing streak (3+ losses), drop back down.\n\nThis "grinding up" approach protects your bankroll while allowing growth.',
          ),
          LessonSection(
            heading: 'Tilt Control',
            body:
                'After a loss, you\'ll feel the urge to immediately queue again with a bigger bet to "win it back." This is tilt — emotional decision-making. It almost always leads to bigger losses. After a loss, take a 5-minute break. Review what went wrong. Then decide calmly whether to play again.',
          ),
        ],
        keyTakeaways: [
          'Never bet more than 25% of your total balance on one match.',
          'Move up stakes only after proven profitability.',
          'Drop down after losing streaks.',
          'Recognize and control tilt — take breaks after losses.',
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
                'Fear makes you close winning trades too early and hesitate on good setups. Greed makes you hold losing trades too long and overleverage. Recognizing these emotions in real-time is a skill that separates winning traders from losing ones. Before every trade, ask: "Am I making this decision based on analysis or emotion?"',
          ),
          LessonSection(
            heading: 'The Plan Before the Match',
            body:
                'Enter every match with a plan: What\'s the current trend? Which assets look strongest? What leverage will I use? What\'s my max position size? Having a plan prevents impulsive decisions. You don\'t need to predict the market — you just need a framework for reacting to what happens.',
          ),
          LessonSection(
            heading: 'Accepting Losses',
            body:
                'Losses are part of trading. Even the best SolFight players lose 30-40% of their matches. What makes them profitable is that their wins are bigger than their losses (thanks to good risk management and reward-to-risk ratios). Accept that some matches are unwinnable — the market moved against you, the opponent got lucky, or your read was wrong. Move on.',
          ),
        ],
        keyTakeaways: [
          'Emotion is the enemy — trade based on analysis, not feelings.',
          'Have a plan before every match starts.',
          'Losing is normal — focus on making wins bigger than losses.',
          'Review every match afterward to improve.',
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
        subtitle: 'Use the Arena info to your advantage',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Opponent ROI Tracking',
            body:
                'The Arena toolbar shows your opponent\'s ROI in real-time. If they\'re up big, they might become conservative — protecting their lead. If they\'re down, they might take aggressive risks. Use this information to adjust your strategy. When you\'re ahead, play defense. When you\'re behind, take calculated risks.',
          ),
          LessonSection(
            heading: 'Position Count Signals',
            body:
                'You can see how many open positions your opponent has. If they have 0, they might be waiting for an entry or conserving their lead. If they have multiple positions, they\'re spreading risk. A sudden increase in positions might mean they\'re making a big move to catch up.',
          ),
          LessonSection(
            heading: 'Chat Mind Games',
            body:
                'The Arena chat lets you communicate with your opponent. Some players try to psych you out or distract you. Stay focused on your charts and strategy. You can also use chat strategically — a confident "GL" at the start can set the tone, but don\'t let trash talk affect your decisions.',
          ),
        ],
        keyTakeaways: [
          'Monitor opponent ROI to adapt your aggression level.',
          'When ahead, play defensive. When behind, take calculated risks.',
          'Opponent position count reveals their strategy.',
          'Don\'t let chat distract you from the charts.',
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
                'BTC, ETH, and SOL are correlated but not identical. BTC leads the market — when BTC makes a big move, ETH and SOL usually follow. However, SOL is more volatile and often moves more in percentage terms. ETH sits in the middle. Understanding these relationships helps you choose which asset to trade at any moment.',
          ),
          LessonSection(
            heading: 'Rotation Strategy',
            body:
                'During a match, don\'t commit to one asset. Start by watching all three. If BTC breaks out of a range, SOL will likely follow with a bigger move — open your position on SOL for amplified returns. If the market is choppy, look for the one asset showing the clearest trend and focus there.',
          ),
          LessonSection(
            heading: 'Hedging Across Assets',
            body:
                'In longer matches, you can hedge by going long on one asset and short on another. If BTC is showing strength relative to SOL, go long BTC and short SOL. This way, even in a market-wide dump, your BTC position loses less than your SOL short gains. This advanced technique reduces directional risk.',
          ),
        ],
        keyTakeaways: [
          'SOL is most volatile, BTC is most stable, ETH is in between.',
          'When BTC leads, SOL follows with bigger moves.',
          'Focus on the asset with the clearest signal.',
          'Hedging (long one, short another) reduces overall risk.',
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
                'Look for: Sudden large candles with long wicks (overextension). Price far from the moving average. Multiple consecutive candles in one direction (exhaustion). In a 15m match, even a 0.5% spike can be an overreaction in crypto. Enter a counter-trade with tight stops above the extreme.',
          ),
          LessonSection(
            heading: 'When NOT to Mean-Revert',
            body:
                'Don\'t fade a strong trend just because it "looks overextended." If BTC is breaking out above major resistance on huge volume, that\'s a real move, not an overreaction. Mean reversion works best in ranging markets or during low-volume spikes. In strong trends, trade WITH the momentum instead.',
          ),
        ],
        keyTakeaways: [
          'Mean reversion = bet that overreactions will correct.',
          'Works best in ranging, choppy markets.',
          'Don\'t fight strong trends with real volume behind them.',
          'Use tight stops when mean-reverting — you\'re trading against momentum.',
        ],
      ),
      Lesson(
        id: 'ad_4',
        title: 'Match Endgame Tactics',
        subtitle: 'Win the final minutes',
        readMinutes: 3,
        sections: [
          LessonSection(
            heading: 'Managing a Lead',
            body:
                'If you\'re ahead with 5 minutes left, your goal shifts from making money to not losing your lead. Close risky positions. Reduce leverage. Move to cash if your lead is comfortable. Your opponent will be forced to take big risks — let them make mistakes while you play it safe.',
          ),
          LessonSection(
            heading: 'Comeback Strategy',
            body:
                'If you\'re behind with time running out, you need to take bigger swings. Increase leverage slightly, look for the highest-conviction setup, and go for it. But don\'t blindly max leverage on a coin flip — even when behind, identify a real setup. A well-timed reversal trade with higher leverage can close a big gap quickly.',
          ),
          LessonSection(
            heading: 'The Final 60 Seconds',
            body:
                'In the last minute, positions auto-close at match end. If you\'re ahead, consider closing all positions manually to lock in your exact P&L (in case a sudden price swing before auto-close hurts you). If you\'re behind, keep your positions open — you need the volatility to close the gap. The endgame is where matches are won and lost.',
          ),
        ],
        keyTakeaways: [
          'When ahead: reduce risk, protect the lead.',
          'When behind: increase conviction, not recklessness.',
          'Consider closing manually before auto-close if you\'re winning.',
          'The last few minutes are the most decisive — stay focused.',
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
  GlossaryTerm(term: 'Leverage', definition: 'Multiplier that amplifies your position size relative to your collateral. 10x leverage = 10x gains/losses.'),
  GlossaryTerm(term: 'Liquidation', definition: 'Forced closure of your position when losses consume your collateral.'),
  GlossaryTerm(term: 'Stop Loss (SL)', definition: 'An order that automatically closes your position at a set loss level.'),
  GlossaryTerm(term: 'Take Profit (TP)', definition: 'An order that automatically closes your position at a set profit level.'),
  GlossaryTerm(term: 'PnL', definition: 'Profit and Loss — the dollar or percentage gain/loss on a position or portfolio.'),
  GlossaryTerm(term: 'ROI', definition: 'Return on Investment — your percentage gain/loss relative to your starting balance.'),
  GlossaryTerm(term: 'Equity', definition: 'Your total account value including unrealized profits/losses from open positions.'),
  GlossaryTerm(term: 'Candlestick', definition: 'A chart element showing open, close, high, and low prices for a time period.'),
  GlossaryTerm(term: 'Support', definition: 'A price level where buying pressure prevents further decline.'),
  GlossaryTerm(term: 'Resistance', definition: 'A price level where selling pressure prevents further increase.'),
  GlossaryTerm(term: 'Breakout', definition: 'When price moves above resistance or below support with conviction.'),
  GlossaryTerm(term: 'Scalping', definition: 'Making many small, quick trades to capture tiny price movements.'),
  GlossaryTerm(term: 'Swing Trading', definition: 'Holding positions longer to capture larger price moves.'),
  GlossaryTerm(term: 'Mean Reversion', definition: 'A strategy that bets on price returning to its average after an extreme move.'),
  GlossaryTerm(term: 'Doji', definition: 'A candlestick with nearly equal open and close, signaling market indecision.'),
  GlossaryTerm(term: 'Engulfing', definition: 'A large candle that completely covers the previous candle — signals reversal.'),
  GlossaryTerm(term: 'Escrow', definition: 'A smart contract that holds both players\' bet amounts until the match ends.'),
  GlossaryTerm(term: 'Tilt', definition: 'Emotional state after a loss that leads to impulsive, often poor decisions.'),
  GlossaryTerm(term: 'USDC', definition: 'A stablecoin pegged to the US Dollar, used for bets and winnings on SolFight.'),
  GlossaryTerm(term: 'Devnet', definition: 'Solana\'s test network with free tokens — used for practice before mainnet.'),
  GlossaryTerm(term: 'Gamer Tag', definition: 'Your display name on SolFight, visible to opponents and on leaderboards.'),
  GlossaryTerm(term: 'Reward-to-Risk Ratio', definition: 'How much you stand to gain vs how much you risk. 2:1 means targeting \$2 profit for every \$1 risked.'),
];
