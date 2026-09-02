# Memo: When would AWS CDK beat Terraform for Kente Retail?

**To:** Kente Retail CTO **From:** Bilal Abubakari **Re:** Terraform vs AWS CDK —
for *us*, not in the abstract.

You asked the fair question: we just built this on Terraform — would AWS CDK have
been the better tool? The honest answer is **not for what we built, but there is a
specific point at which it would be.** Here is where that line is, grounded in
Kente's actual situation.

## Where the two genuinely differ

Terraform describes infrastructure in HCL, a declarative configuration language.
CDK lets you describe it in a **real programming language** (TypeScript, Python,
etc.) that *synthesises* CloudFormation. So the real trade is: HCL's simplicity
and multi-cloud reach, versus a general-purpose language's loops, types, unit
tests, and IDE support — at the cost of being **AWS-only** and sitting on top of
CloudFormation's behaviour (including its slower, sometimes rougher rollbacks).

## Reading that against Kente's reality

| Factor | Kente today | Points to |
|---|---|---|
| Cloud footprint | 100% AWS, no sign of multi-cloud | neutral→CDK (Terraform's portability is unused) |
| Team language | This stack is HCL + a little Python/bash | Terraform (no TS/Python app team to leverage) |
| Infra complexity | One web tier, two near-identical envs | Terraform (HCL is plenty; CDK's abstraction is idle) |
| The thing we keep varying | Per-environment *values* in a map | Terraform (this is config, not logic) |
| Existing investment | A working, just-refactored Terraform codebase + remote state | Terraform (switching cost is real, benefit is not) |

For the environment we just delivered, **Terraform is the correct tool** and CDK
would have been a lateral move at best: our dev/staging difference is a handful of
values in a map, which is a configuration problem, not a programming one. CDK's
headline strength — expressing infrastructure as code with loops and abstractions
— buys nothing when the variation is "t3.micro here, t3.small there."

## The specific point where CDK becomes the better fit

CDK would overtake Terraform for Kente **when the infrastructure itself becomes
logic rather than configuration** — concretely, any of:

1. **Per-tenant / per-store stacks.** Kente is a retailer. The day "spin up an
   isolated stack per store or per client" arrives — dozens or hundreds of
   near-identical-but-parameterised stacks generated from a list — CDK's ability
   to loop and compose in a real language, with types and unit tests over the
   generated stacks, pulls decisively ahead of HCL's `for_each`/module gymnastics.
2. **An app team that already lives in TypeScript/Python.** If the order-service
   engineers own infrastructure and are fluent in one language, CDK removes the
   HCL context-switch and lets infra share the app's tooling, tests, and review
   habits. Ownership by app developers is CDK's real sweet spot.
3. **Deep, opinionated use of higher-level AWS constructs.** CDK's L2/L3
   constructs bake in AWS best-practice defaults (a Fargate service, an ALB, its
   IAM, its log wiring, in a few lines). If Kente commits hard to serverless/ECS
   and wants those batteries-included defaults, CDK is more ergonomic than
   assembling the equivalent Terraform resources.

## Recommendation

Stay on Terraform for this engagement — it fits the current shape of the problem
and we have just made it good. **Re-open the question if** Kente moves to
per-store isolated stacks, hands infrastructure ownership to a TypeScript/Python
app team, or standardises on ECS/Fargate with heavy use of AWS L2 constructs. The
trigger is *infrastructure becoming logic*; until then, HCL's simplicity is a
feature, not a limitation, and the multi-cloud portability we'd be paying HCL's
verbosity for is portability Kente isn't using.
