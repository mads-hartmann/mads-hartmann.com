---
layout: post-no-separate-excerpt
title: "Using AI to do your best work"
date: 2026-01-27 12:00:00
colors: pinkred
---

I am by no means the most advanced user of AI, but I do try to challenge my way of working quite often to find the techniques and workflows that work best for me.

One question that I found really useful to guide these explorations is "how can AI enable me to do my best work more often?"

I also try to find ways to be more productive in the "ship more features and bug fixes faster"-sense but for this post I want to focus on raising the bar on the quality of my work, as I find that really interesting too.

Here's an example from last week where I ended up landing on a workflow that I'll call "Hypothesis based explorations and chasing the good explanations". Nice and short.

## A worthy bug

For streaming your conversations with [Ona](https://ona.com/) we use [jsonl](https://jsonlines.org/) which we then process on the client into a structure suitable for rendering with React.

When there are issues with how conversations render, or the agent acts weird, users can send us a support bundle that containers information about the agents memory, logs, as well as this conversation stream.

I have built [some cool tools](https://x.com/Mads_Hartmann/status/2009701216079753474) for debugging how we process and render the stream but, unfortunately, one of our power users would hit an issue several times a week that we couldn't reproduce from the support bundle; when processing the `jsonl` stream everything was fine. Likewise, if the user refreshed their browser, the issue would go away.

## Hypothesis based exploration

Keeping "how can AI enable me to do my best work more often?" in mind, I thought what would an excellent fix look like?

- A thorough explanation of why the issue occurs
- A regression test that shows how to reliably reproduce the issue
- A simple fix

So, lets just try to ask for that and see what happens[^1]

> It looks like that conversation streaming can skip blocks/lines sometimes, and its especially visible when those blocks are TODO related. Refreshing the UI fixes the issue, and if you look at the conversation stream the json all looks fine. I suspect this has something to do with how we handle the conversation caching, but I'm open to other suggestions. <br /><br />
>
> I've mostly experienced it when navigation back to conservation I had previously loaded some of, but then the agent worked on the issue and I came back. That's why I feel like the conversation cache might be part of the issue. <br /><br />
>
> Please do a deep analysis of the client-side conversation streaming code. Consider any conditions that could cause what I'm seeing. <br /><br />
>
> What I'm most interesting in right now it to be able to clearly reproduce the problem. In the ideal situation we can write a test that shows how lines can be skipped under certain conditions.

With a little bit of extra prompting, Ona had 5 different hypothesis for what might have caused the issue:

1. Race Condition - Old Stream Pushes to Reset Array
2. Cache Overwrites with Partial Data
3. Byte-Offset Slicing with Different Server Data
4. TODO Blocks Lack Sequence IDs for Proper Deduplication
5. IndexedDB Slowness on Firefox Creates Race Windows

Of those 5 I could dismiss 2 but the remaining 3 sounded plausible enough so I had Ona write them to separate files:

> I don't care about 3 as we don't change the server data often enough. I don't care about 4 because when I look at the conversation JSON it all looks correct. <br /><br />
>
> For case 1,2, and 5 write down your hypothesis in separate markdown files. Explain the problem, your hypothesis. I will use these to investigate separately.

I pushed the files to a branch and started three separate environments so I could work through the hypotheses in parallel. I wrote a prompt similar to this one for each of them:

> Help me explore if hypothesis in frontend/dashboard/src/hooks/HYPOTHESIS-1-race-condition-old-stream.md is a good hypothesis. Consider it critically. Your goal is to produce a test case that's able to reproduce the issue today or show why the hypothesis is incorrect.

Working with Ona we quite quickly eliminated two:

- Cache Overwrites with Partial Data: "The mechanism is real but doesn't cause data loss". It did reveal that our cache is a bit inefficient, but that's not what I care about right now.
- IndexedDB Slowness on Firefox Creates Race Windows: "The hypothesis claims this causes data loss - it doesn't.". This just turned out not to be an issue.

The last one **Race Condition - Old Stream Pushes to Reset Array** seemed really promising.

## Chasing the good explanations

For this one, Ona was able to produce a unit test that could simulate conditions that would cause our React hook to return incorrect data, however:

- The unit test didn't test our hook, but a partially copy-based version of the implementation.
- The explanation of what could cause the conditions didn't feel quite right

So I pressed on. I'll admit this part felt really frustrating at the time. Ona would - with blatant confidence - pronounce to have an explanation only to be easily proven wrong. Then she would go the other way and say "actually, there is no race condition" where I'd then read the code closely and point out that "line XYZ looks like a race condition to me".

While it is frustrating (and disappointing) to get explanations that are not quite right, I have started to think of it differently. When I get an explanation I use that a way to test my own understanding of the issue. If I don't feel confident in the explanation I just ask for evidence that would convince me.

That way it feels more like a collaboration to find a "good explanation" and with that mindset I find it really rewarding; the goal is for **me** to feel confident in the explanation. For this issue I ended up improving my understanding of some React internals and React Query details; things that will make it easier to me to challenge Ona on explanations in the future.

## Does it matter?

The PR I opened has a good explanation, a test that reproduces the race condition reliably, and a simple fix. But that simple fix. It was also present in the original response to my very first prompt, and was deemed "Most Likely for Frequent Issues". I could have just had Ona fix that and moved on. But I wouldn't have understood why it fixed it, and for now, that still feels important to me.

This way of methodically working through hypotheses chasing the good explanation feels like a really great way to build out that understanding.

And it really wasn't that much effort, it took me about 1.5 hours of focused time spread over 2 days. Without AI it could easily have taken me a full day to arrive at the same solution with the same level of confidence in the fix.

[^1]: This prompt is now very strong, and it's once of the things I'll be tweaking over the next couple of weeks as I iterate on this workflow, but I am often surprised by how far you can get with just asking for what you want rather than try to produce the best possible prompt.
