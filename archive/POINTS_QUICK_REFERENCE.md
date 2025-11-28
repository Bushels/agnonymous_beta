# Agnonymous Point System - Quick Reference

## 📊 How to Earn Points

### **Actions You Control**

| Action | Points | Frequency | Notes |
|--------|--------|-----------|-------|
| Create a post | **+5** | Every post | Immediate reward |
| Comment on a post | **+2** | Once per post | Reply 100x = still only 2 pts |
| Vote on a post | **+1** | Once per post | Any vote type counts |

**Maximum from interacting with one post:** 3 points (1 vote + 2 comment)

---

### **Community Validation (Your Posts)**

Based on how others vote on YOUR posts:

| Vote Pattern | Points | Explanation |
|--------------|--------|-------------|
| **2+ thumbs up** 👍👍 | **+2** | Community confirms accuracy |
| **1 thumbs up** 👍 | **+1** | Some validation |
| **1 thumbs down** 👎 | **0** | No penalty yet |
| **2+ thumbs down** 👎👎 | **-1** | Community doubts accuracy |

**Maximum loss per post:** -5 points (can only lose what you earned from posting)

**Vote scoring is cumulative:** If you have 3 thumbs up and 1 thumbs down, net = 2 thumbs up → +2 points

---

### **Admin Verification (Bonus)**

| Verification Type | Points | Who Gets It |
|-------------------|--------|-------------|
| Post marked "Verified Truth" | **+10** | Post author |
| Verified truth one-time bonus | **+5** | Post author |

**Total admin verification bonus: +15 points**

---

## 🌡️ Truth Meter Explained

Every post gets a **Truth Meter** score based on voting:

### **How It's Calculated:**

```
Accuracy = (Thumbs Up + Partial×0.5) / Total Votes × 100%
```

**Example:**
- 10 thumbs up 👍
- 3 partial 🟡
- 2 thumbs down 👎
- Total: 15 votes
- Score: (10 + 3×0.5) / 15 = 77% → **Likely True**

### **Truth Meter Statuses:**

| Status | Accuracy | Min Votes | What It Means |
|--------|----------|-----------|---------------|
| ❓ **Unrated** | N/A | 0 | No votes yet |
| 🚨 **Rumour** | <30% | 3+ | Likely false/misleading |
| ⚠️ **Questionable** | 30-49% | 3+ | Conflicting evidence |
| 🟡 **Partially True** | 50-69% | 3+ | Some truth, some doubt |
| ✓ **Likely True** | 70-89% | 3+ | Probably accurate |
| ✓✓ **Verified by Community** | 90%+ | 5+ | Highly credible |
| 🛡️ **Verified Truth** | Admin | N/A | Admin confirmed |

---

## 🏆 Reputation Levels

Your total reputation points determine your level and perks:

| Level | Points | Title | Badge | Vote Weight | Special Perks |
|-------|--------|-------|-------|-------------|---------------|
| 0 | 0-49 | Seedling | 🌱 | 1.0x | - |
| 1 | 50-149 | Sprout | 🌿 | 1.0x | - |
| 2 | 150-299 | Growing | 🌾 | 1.1x | Slightly stronger votes |
| 3 | 300-499 | Established | 🌳 | 1.2x | - |
| 4 | 500-749 | Reliable Source | ⭐ | 1.3x | - |
| 5 | 750-999 | Trusted Reporter | ⭐⭐ | 1.5x | Can nominate for admin review |
| 6 | 1000-1499 | Expert Whistleblower | ⭐⭐⭐ | 1.7x | See partial voter stats |
| 7 | 1500-2499 | Truth Guardian | 🏅 | 2.0x | Request admin verification |
| 8 | 2500-4999 | Master Investigator | 🏅🏅 | 2.5x | Moderator eligible |
| 9 | 5000+ | Legend | 👑 | 3.0x | Top leaderboard tier |

### **What is Vote Weight?**

Vote weight makes your votes count more as you level up:
- **Level 0-1 (1.0x):** Your vote = 1 point to the truth meter
- **Level 5 (1.5x):** Your vote = 1.5 points to the truth meter
- **Level 9 (3.0x):** Your vote = 3 points to the truth meter

**Why?** This rewards building reputation and makes it harder for new accounts to manipulate voting.

---

## 🎯 Example Scenarios

### **Scenario 1: New User Posts**

```
Action: Create post about price fixing
Points earned: +5 (immediate)

Community votes:
- 5 thumbs up 👍
- 1 thumbs down 👎
- Net: 4 thumbs up (>2 threshold)

Points earned: +2 (vote bonus)

Admin sees post, investigates, confirms true
Points earned: +10 (verification) + +5 (verified bonus)

Total from this post: 5 + 2 + 15 = 22 points!
```

### **Scenario 2: User Interacts with Others' Posts**

```
You find 3 interesting posts:

Post 1:
- Vote thumbs up: +1
- Comment "I saw this too": +2
- Subtotal: 3 points

Post 2:
- Vote partial: +1
- Don't comment: 0
- Subtotal: 1 point

Post 3:
- Just read, no interaction
- Subtotal: 0 points

Total earned: 4 points
```

### **Scenario 3: False Post Gets Downvoted**

```
Action: Create sensational but false post
Points earned: +5 (initial)

Community votes:
- 1 thumbs up 👍
- 8 thumbs down 👎
- Net: 7 thumbs down (>2 threshold)

Points deducted: -1 (penalty)

Truth Meter: 11% → "Rumour" 🚨

Net points from post: 5 - 1 = 4 points
(You don't lose more than you gained)
```

---

## 🛡️ Anti-Abuse Rules

### **What You CANNOT Do:**

1. ❌ **Vote on your own posts** → Blocked by system
2. ❌ **Get comment points multiple times on same post** → Only first comment counts
3. ❌ **Vote multiple times on same post** → Prevented by unique constraint
4. ❌ **Rapid-fire vote 10+ posts in 5 min** → Flagged as suspicious
5. ❌ **Reputation below 0** → Floor enforced

### **How We Prevent Gaming:**

- **Vote weighting** - High-rep users' votes count more
- **Self-voting blocked** - Can't upvote your own posts
- **One-time bonuses** - Comment/vote points once per post
- **Loss limits** - Can't lose more than you gained from post
- **Suspicious activity logging** - Rapid voting flagged
- **Admin verification** - Human review for important claims

---

## 📈 Tips for Building Reputation

### **Best Strategies:**

1. **Post accurate, verified information** → Avoid downvotes
2. **Provide evidence when possible** → Increases admin verification chances
3. **Comment thoughtfully** → 2 points per unique post you engage with
4. **Vote on quality posts** → 1 point each, adds up quickly
5. **Be consistent** → Regular participation builds reputation over time

### **Avoid These:**

1. ❌ Posting rumors without verification → Gets downvoted
2. ❌ Spamming comments → Only first comment on each post counts
3. ❌ Vote brigading → Gets you flagged
4. ❌ Sensationalism without facts → Harms truth meter score

---

## 🏅 Leaderboards

You'll appear on leaderboards based on:

1. **All-Time Top Contributors** - Total reputation points
2. **Most Verified Posts** - Admin confirmations
3. **Most Accurate Reporters** - Average truth meter score (min 10 posts)
4. **This Month's Heroes** - Points earned in last 30 days

**Only public reputation is shown** - Your anonymous posts still earn you points, but they count toward your private reputation.

---

## 💡 Remember

- **Quality over quantity** - One verified post = more points than 10 rumors
- **Community decides** - Truth meter based on collective voting
- **Anonymity preserved** - Points from anonymous posts still count
- **Can't go negative** - Reputation floor = 0 points
- **Vote weight matters** - Build reputation to increase influence

**The goal:** Encourage accurate reporting and reward truth-tellers, even if they need to stay anonymous! 🎯
