Basic assumption: 
A license is to make a derivative

# Starting from Not a derivative

Bob owns IP1
1) If Bob adds 1 Policy in IP -> others can mint if they pass verifications ✅
1) If Bob doesn't set Policy in IP -> others can't mint✅
2) Bob can mint Licenses with whatever Policy in any of the above✅

3) Bob can add different policies on IP1 without compatibility checks. Others can mint licenses to make derivatives of IP1 from each different policy, as long as they pass the verifications✅

4) Bob can mint licenses with different policies, transfer to others, and the holders can make derivatives from each License, regardless of IP1 having several policies set✅
   
5) Bob has set P1 and P2 in IP1, and gets license(LE) with PE from Emergence (IPE)
   Bobs wants to set IPE as parent of IP1
    6.1) If the policies that IP1 has are in conflict with PE, revert 🚧
    6.2) If the policies that IP1 has are not in conflict with PE, OK -> IP1 adds PE, IPE parent of IP1 🚧
    6.3) Bob disable conflicting policies, then Adds PE 🚧

# Starting from A Derivative

Bob owns IP1
Bob creates a license L1 with P1
Alice owns IP2
Alice burns L1, P1 is set in IP2

1) P1 does not allow for derivatives 🚧
1.1) Don tries to mint a license from P1 in IP2 -> fails 🚧
1.2) Alice tries to mint a license from P1 in IP2 -> fails 🚧
1.3) Alice tries to mint 🚧

// Edge case, later on, Alice buys the right from her licensor to make derivatives
// Setting the parent again should work in this case, P2 should be
1.4) Bob mints L2 with P2 (allows derivatives) and sends it to Alice 🚧
     Alice burns L2 and P2 is set in IP2 🚧
     Alice can mint now L3 with P2? 🚧


1) P1 allows for derivatives of this derivatives, but meaning P1 propagates down, no other can be set (reciprocal == true) 🚧
2.1) Don tries to mint a license from P1 in IP2 -> License mints, has P1 🚧
2.2) Alice tries to mint a license from P1 in IP2 -> License mints, has P1 🚧
2.3) Alice tries to set P2 in IP2 -> Fails, reciprocal means no different policies allowed, 
and you cannot add the same policy twice 🚧

# Commercial
Bob owns IP1 
Bob creates a license L1 with P1
Alice owns IP2
Alice burns L1, P1 is set in IP2

1) P1 is Non Commercial (assume derivatives allowed)
1.1) Alice tries to mint a commercial license -> fail🚧
1.2) Alice tries to add a commercial policy -> fail🚧

2) P1 is Commercial (assume derivatives allowed)
1.1) Alice tries to mint a non commercial license -> OK? (if the only derivatives of derivatives are reciprocal, this fails)🚧
1.2) Alice tries to add a commercial policy -> OK? (if the only derivatives of derivatives are reciprocal, this fails)🚧


# Setting multiple parents
Bob owns IP1, IP2 and IP3
Bob mints L1 with P1 from IP1
Bob mints L2 with P2 from IP2
Bob mints L3 with P3 from IP3

Alice owns IP4
Alice wants to burn L1,L2 and L3 to link as parents for IP4
1) If one is reciprocal, all Ps have to be the same or fail. Result is verify all 3, set 1 policy set for IP4🚧
2) If no reciprocal, some parameters make the operation impossible, others are indifferent as long as validations pass🚧

-- Attribution is indifferent
-- Transferable is ???
-- Commercial use: must be all equal or fail
-- Commercial attribution: indifferent
-- Commercializers:
  - All empty -> OK, stays empty
  - 1 has values -> OK, the 1 with values wins
  - several have same values -> OK, same values
  - some have different values -> fail
-- Commercial rev share: set all
-- derivatives allowed: derivatives are only allowed through 1)
-- derivativesAttribution: indifferent
-- derivativesApproval: verify the ones that have it
-- derivativesReciprocal: see 1)
-- derivativesRevShare: execute all, but it should be case 1)
-- Territories: same logic as Commercializers
-- Distribution Channels: same logic as Commercializers
-- Content Restrictions: same logic as Commercializers


# Demo use case

| Demo Use Case                   |                                                            Social Remixing                                                            |                                                               Commercial Activity                                                               |
|---------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------:|
| Purpose                         | Allow users to add multiple layers of creativity to an original work, with appropriate attribution and control for the source creator | Monetize an original work                                                                                                                       |
| License flavor                  | Non-commercial remix with attribution, reciprocal license                                                                             | Permissionless commercial license with attribution                                                                                              |
| What makes this unique?         | Endless remixing - tracking all the uses of a work, and giving the creator full credit                                                | Provides the creator with full control over the uses of her work, while allowing any 3rd party to appropriately use the work for fair economics |
|                                 |                                                                                                                                       |                                                                                                                                                 |
| Parameters - all default EXCEPT |                                                                                                                                       |                                                                                                                                                 |
| Attribution                     | Tagged                                                                                                                                | Tagged                                                                                                                                          |
| Derivatives                     | Allowed-With-Attribution Allowed-With-Reciprocal License                                                                              |                                                                                                                                                 |
| Commercial Use                  |                                                                                                                                       | Allowed-With-Attribution                                                                                                                        |
| License Fee                     |                                                                                                                                       | One-Time LicenseFee Actual fee TBD by Creator                                                                                                   |

P1 - Social Remixing
P2 - Commercial Activity

So we have:
An original work A, has P1 and P2 set
people can remix A  into B and B into C, all of with P1
B can buy P2 from A.
C can't buy P2 from A?
C can't buy P2 from B?
Once B has bought P2, C can buy P2 from B?


# DISPUTED CASES

# Plagiarism
Bob owns IP1 
Bob sets P1 in IP1 (he can, since he clains IP1 is original)
Alice owns IP2
Alice mints L1 from IP1-P1
Alice links IP2 to IP1 with L1
Don finds out IP1 plagiarizes his IP0
Don raises dispute against IP1 for plagiarism
Dispute passes, IP1 is labeled as plagiarism
Bob cannot set policies in IP1
Bob cannot mint licenses from IP1
Alice cannot set policies in IP2
Alice cannot mint licenses from IP2
// TODO: royalties?

# Unnatributed derivative
Bob owns IP1 
Bob sets P1 in IP1 (he can, since he clains IP1 is original)
Alice owns IP2
Alice mints L1 from IP1-P1
Alice links IP2 to IP1 with L1
Don finds out IP1 is a clear derivative of his IP0
Don raises dispute against IP1 for unatributed derivative
Dispute passes, IP1 is labeled as plagiarism
??? Either:
Bob cannot set policies in IP1
Bob cannot mint licenses from IP1
Alice cannot set policies in IP2
Alice cannot mint licenses from IP2
// TODO: royalties?
???? Or:
IP1 is forced to set IP0 as parent, 
All policies from IP1 are disabled and IP0 policy is set instead
// Does this propagate through children/royalties?
