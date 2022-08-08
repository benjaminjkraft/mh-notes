---
title: Minlucks & floating point errors
date: August 7, 2022
---

## Background

The current accepted [catch rate formula](https://github.com/tsitu/MH-Tools/blob/master/README.md#-new-formula) is as follows:

$$ CR = \frac{E * P + 2 * \operatorname{floor} (\min(1.4, E) * L)^2}{E * P + M} $$

where $P$ and $L$ are the setup's power and luck, respectively, $E$ is the trap power type's effectiveness against the mouse (often expressed as a percentage), $M$ is the mouse's power, and $\operatorname{floor}$ rounds its argument down to the nearest integer. After some algebra results in the following formula for the minimum luck needed to guarantee you'll catch a mouse (the "minluck"):

$$ ML = \operatorname{ceil}\left(\frac{\operatorname{ceil}\left(\sqrt{\frac{M}{2}}\right)}{\min(1.4, E)}\right) $$

For most mice this seems to be correct, but for a few mice there's evidence of misses at the supposed minluck, including a screenshot of a miss of Zealous Academic with 85 luck.

## Dave's post

On August 5, in response to questions from seli and others, [Dave posted screenshots](https://discord.com/channels/275500976662773761/355474934601875457/1005190015376183296) from the devs' internal CRE showing that Zealous Academic has a 97% catch rate at 85 luck and 15351 power, and a 100% catch rate at 86 luck and the same power. He also [confirmed](https://discord.com/channels/275500976662773761/355474934601875457/1005184813151559822) that Zealous Academic has a mouse power of 28,000 and a Shadow effectiveness of 600%, along with some other comments about how the formula has some quirks due to its history. This confirms that our catch rate formula is not quite right.

## Floating point errors

The proposed hypothesis is that the source of the minluck discrepancy is *floating point errors*, which come from the way computers typically represent non-integer arithmetic (as "floating point numbers" or "floats"). This representation cannot represent most decimal numbers exactly, and arithmetic operations on those numbers can cause surprising results. [Wikipedia](https://en.wikipedia.org/wiki/Floating-point_arithmetic#Accuracy_problems) describes the problem in much greater detail, but for our purposes all we need to know that computers actually represent the number `1.4` as `1.399999999999999911182158029987476766109466552734375`, which is an error of about 0.0000000000000063%. (Actually, there are two representations, IEEE 754 32- and 64-bit floats, with different accuracy; the errors here only come out right if MouseHunt uses 64-bit floats so that's what we're using.)

Normally, such errors are tiny, but the floor function used in the catch rate formula makes them larger. Specifically, we hit minluck if

$$ 2 * \operatorname{floor}(\min(1.4, E) * L)^2 \geq M $$

For Zealous Academic ($E = 6$ and $M = 28000$) at 85 luck, that becomes $ 2 * \operatorname{floor}(1.4 * 85)^2 \geq 28000 $. Now mathematically, `1.4 * 85 = 119`, so the left side is `2 * 119² = 28322 ≥ 28000`, so we hit minluck. But in floating-point land, we actually compute `1.3999999999999999111... * 85 = 118.99999999999999245...`, which is again off by some tiny fraction, but it's less than 119, so the floor is 118, not 119. Sadly, `2 * 118² = 27848 < 28000`, so we no longer minluck.

## Changed minlucks

Only some mice are affected by this change; for example any mouse/type with 100% efficacy will be unaffected, since 1 is representable exactly as a 64-bit float. Specifically, the following mice are currently affected, and under this theory have minluck 1 higher than the above formula would indicate:

- Blacksmith, Glass Blower with Physical, Tactical, Law: 85 → 86
- Drudge, RR-8, Summoning Scholar with Forgotten: 45 → 46
- Paladin with Arcane, Draconic, Forgotten, Hydro, Shadow: 45 → 46
- Treasure Brawler with Forgotten: 85 → 86
- Zealous Academic with Shadow: 85 → 86

Data from MHCT confirms misses for Blacksmith, Drudge, RR-8, Summoning Scholar, and Paladin; Glass Blower, Treasure Brawler, and Zealous Academic have too few hunts at exactly the relevant luck to tell (15, 4, and 33, respectively; of course Zealous was confirmed by Dave as well as several Discord users).

## Changed catch rates

When computed with floating-point numbers, the catch rate formula above gives a catch rate of 99.88% with the setup Dave posted at 85 luck; this is obviously both less than 100% and greater than 97%. This is consistent with observations in the community that some or all mice seem to have a lower-than-expected catch rate when near, but not at, minluck. The above theory gives no explanation for this phenomenon, it just changes when it would kick in.

## Computing correct minlucks

### Using 64-bit float arithmetic

For tool authors already using 64-bit float arithmetic (including those writing in JavaScript, PHP, Google Apps Script, Python, and most other programming languages with a "float64" or "double" type) no changes to the above formula are necessary, although authors working with trap effectiveness as a percentage must divide it by 100 before multiplying by the luck (i.e. `min(140, eff) / 100 * luck`, not `min(140, eff) * luck / 100`. To compute minlucks, one can just use the above formula, then check if `2 * floor(min(1.4, eff) * candidate_minluck)^2` is at least the mouse power; if not then increment the minluck by 1.

### Using Google Sheets

For tool authors using Google Sheets the situation is much more complicated. Google Sheets actually also uses 64-bit float arithmetic but to avoid exposing such problems to the user it rounds values to 15 decimal significant figures before any rounding operations as well as before displaying to the user. For the catch rate formula, one can replace `FLOOR(X)` with `IF(X-FLOOR(X) >= 0, FLOOR(X), FLOOR(X)-1)` (mathematically, the `IF` always takes the first branch, but when Google Sheets's pre-rounding kicks in, it will take the second branch).

To compute minlucks, Neb has contributed the following formula which implements a similar method to the previous subsection, but using the floor trick:
```
IFERROR(
    IF(
        MIN(Eff/100,1.4)*CEILING(CEILING(SQRT(MousePower/2))/MIN(Eff/100,1.4))
        -FLOOR(MIN(Eff/100,1.4)*CEILING(CEILING(SQRT(MousePower/2))/MIN(Eff/100,1.4)))
        >=0,
        CEILING(CEILING(SQRT(MousePower/2))/MIN(Eff/100,1.4)),
        IF(
            (MIN(Eff/100,1.4)*CEILING(CEILING(SQRT(MousePower/2))/MIN(Eff/100,1.4))-1)^2*2>MousePower,
            CEILING(CEILING(SQRT(MousePower/2))/MIN(Eff/100,1.4)),
            CEILING(CEILING(SQRT(MousePower/2))/MIN(Eff/100,1.4))+1)),
    "9999")
```

Neb's spreadsheet of the new and old minlucks using the above formula is [here](https://docs.google.com/spreadsheets/d/1UHBRqR9oHNTP2aEQJEw1oUcvyIvYIxiRa9-NotuiSDI/edit#gid=759842139).
