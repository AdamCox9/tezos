.. _proof-of-stake:

Proof-of-stake in Tezos
=======================

This document provides an in-depth description of the Tezos
proof-of-stake algorithm. **WORK IN PROGRESS, CONSTANTS STILL SUBJECT TO
ADJUSTMENT.** **THIS DOES NOT CONTAIN CHANGES INTRODUCED BY PVSS.**

Blocks
------

The Tezos blockchain is a linked list of blocks. Blocks contain a
header, and a list of operations. The header itself decomposes into a
shell header (common to all protocols) and a protocol specific header.

Shell header
~~~~~~~~~~~~

The shell header contains

-  ``level``: the height of the block, from the genesis block
-  ``proto``: number of protocol changes since genesis (mod 256)
-  ``predecessor``: the hash of the preceding block.
-  ``timestamp``: the timestamp at which the block is claimed to have
   been created.
-  ``validation_pass``: number of validation passes (also number of
   lists of lists of operations)
-  ``fitness``: a sequence of sequences of unsigned bytes, ordered by
   length and then lexicographically. It represents the claimed fitness
   of the chain ending in this block.
-  ``operations_hash`` The root hash of a merkle tree of a list of root
   hashes of merkle trees for various sets of operations in the block.
-  ``context`` Hash of the state of the context after application of
   this block. Useful for light clients.

Protocol header (for tezos.alpha):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  ``signature``: a digital signature of the shell and protocol headers
   (excluding the signature itself).
-  ``priority``: every block height in tezos.alpha is associated with an
   ordered list of bakers. The first baker in that list is the first one
   who can bake a block at that height, one minute after the previous
   block. The second baker in the list can do so, but only two minutes
   after the previous block, etc., the third baker three minutes after.
   This integer is the priority of the block.
-  ``seed_nonce_hash``: a commitment to a random number, used to
   generate entropy on the chain. Present in only one out of
   (``BLOCKS_PER_COMMITMENT`` = 32) blocks.
-  ``proof_of_work_nonce``: a nonce used to pass a low-difficulty
   proof-of-work for the block, as a spam prevention measure.

Block size
~~~~~~~~~~

Tezos does not download blocks all at once, but rather considers headers
and various lists of operations separately. In Tezos.alpha, a maximum
size in bytes is applied to the list of transactions
``MAX_TRANSACTION_LIST_SIZE`` = 500kB (that's 5MB every 10 minutes at
most).

Other lists of operations (endorsements, denunciations, reveals) are
limited in terms of number of operations (though the defensive
programming style also puts limits on the size of operations it
expects).

This ensure that consensus critical operations do not compete with
transactions for block space.

Delegation
----------

Tezos.alpha uses a delegated proof-of-stake model. The acronym DPOS has come to
designate a specific type of algorithm used, for instance in Bitshares.
This is *not* the model used in Tezos.alpha, though there is a concept
of delegation.

Delegates
~~~~~~~~~

In tezos.alpha, tokens are controlled through a private key called the
*manager key*. Tezos.alpha accounts let the manager specify a public
delegate key. This key may be controlled by the manager themselves, or
by another party. The responsibility of the delegate is to take part in
the proof-of-stake consensus algorithm and in the governance of Tezos.

The manager can generally change the delegate at any time, though
contract can be marked to specify an immutable delegate. Though
delegation can be changed dynamically, the change only becomes effective
after a few cycles.

There are also default accounts in Tezos, which are just the hash of the
public key. These accounts do not have an attached delegate key and do
not participate in the proof-of-stake algorithm.

Finally, delegate accounts (used for placing safety deposits) are
automatically delegated to the delegate itself.

Active and passive delegates
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A delegate can be marked as either active or passive. A passive delegate
cannot be selected for baking or endorsement.

A delegate becomes passive for cycle ``n`` when they fail to create any
of the blocks or endorsements in the past ``CYCLES_BEFORE_DEACTIVATION``
= 5 cycles, or to change their security deposit. So, in this case, in
cycles ``n-1``, ``n-3``, ..., ``n - CYCLES_BEFORE_DEACTIVATION``.

A small delegate who is afraid they might be deactivated because they
were not given the opportunity to create any block or endorsement can
ensure they do not become deactivated by making small, meaningless
transactions with their security deposits once every two cycles.

Discussion: giving ``CYCLES_BEFORE_DEACTIVATION`` a small value means
the chain adapts more quickly to participants disappearing. It's not
unlike the "difficulty adjustment" of Bitcoin. However, a long value
would ensure that a minority fork progresses more slowly for a longer
period of time than the majority fork. ``CYCLES_BEFORE_DEACTIVATION``
gives the majority chain a "headstart".

This does not affect voting rights for protocol changes.

Rolls
~~~~~

In theory, it would be possible to give each token a serial number, and
track the specific tokens assigned to specific delegates. However, it
would be too demanding of nodes to track assignment at such a granular
level. Instead we introduce the concept of rolls. A roll represents a
set of coins delegated to a given key. When tokens are moved, or a
delegate for a contract is changed, the rolls change delegate according
to the following algorithm.

Each delegate has a stack of roll ids plus some "change" which is always
an amount smaller than ``TOKENS_PER_ROLLS``. When tokens are moved from
one delegate to the other, first, the change is used. If it is not
enough, rolls need to be "broken" which means that they move from the
delegate stack to a global, unallocated, roll stack. This is done until
the amount is covered, and some change possibly remains.

Then, the other delegate is credited. First the amount is added to the
"change". If it becomes greater than ``TOKENS_PER_ROLLS``, then rolls
are unstacked from the global unallocated roll stack onto the delegate
stack. If the global stack is empty, a fresh roll is created.

This preserves the property that if the delegate is changed through
several transactions, the roll assignment is preserved, even if each
operation moves less than a full roll.

The advantage of tracking tokens in this way is that a delegate creating
a malicious fork cannot easily change the specific rolls assigned to
them, even if they control the underlying tokens and shuffle them
around.

Rolls hold ``TOKENS_PER_ROLLS`` = 10,000 tokens and thus there should be
about 80,000 rolls in the Tezos foundation's planned genesis block,
though the number of rolls will increase with inflation and / or
participation in the delegation.

Roll snapshots
~~~~~~~~~~~~~~

Roll snapshots represent the state of rolls for a given block. Roll
snapshots are taken every ``BLOCKS_PER_ROLL_SNAPSHOT`` = 256 blocks,
that is 16 times per cycle. There is a tradeoff between memory
consumption and economic efficiency. If roll snapshots are too frequent,
they will consume a lot of memory. If they are too rare, strategic
participants could purchase many tokens in anticipation of a snapshot
and resell them right after.

Cycles
------

Blocks in the Tezos.Alpha Blockchain are grouped into *cycles* of
``BLOCKS_PER_CYCLE`` = 4,096 blocks. Since blocks are at least
``TIME_BETWEEN_BLOCKS`` = one minute apart, this means a cycle lasts *at
least* 2 days, 20 hours, and 16 minutes. In the following description,
the current cycle is referred to as ``n``, it is the nth cycle from the
beginning of the chain. Cycle ``(n-1)`` is the cycle that took place
before the current one, cycle ``(n-2)`` the one before, cycle ``(n+1)``
the one after, etc.

At any point, the tezos shell will not implicitly accept a branch whose
fork point is in a cycle more than ``ALLOWED_FORK`` = 5 cycles in the
past (that is *at least* 14 days, 5 hours, and 20 minutes).

Security deposits
~~~~~~~~~~~~~~~~~

The cost of a security deposit is ``BLOCK_SECURITY_DEPOSIT`` = 512 XTZ
per block created and ``ENDORSEMENT_SECURITY_DEPOSIT`` = 64 XTZ per
endorsement.

Each delegate key has an attached security deposit account controlled by
the same key. Delegates can withdraw and deposit in this account, but
they cannot withdraw more than the "frozen" amount. Each blocks created,
each endorsement signed increases the amount that is frozen.

It is possible to deposit a bond just prior to creating a block
requiring this deposit. Deposits for blocks and endorsements in cycle
``n`` are "unfrozen" at the end of cycle ``n+ALLOWED_FORK``.

Since deposits are locked for a period of ``ALLOWED_FORK`` one can
compute that at any given time, about ((``BLOCK_SECURITY_DEPOSIT`` +
``ENDORSEMENT_SECURITY_DEPOSIT`` \* ``ENDORSERS_PER_BLOCK``) \*
(``ALLOWED_FORK`` + 1) \* ``BLOCKS_PER_CYCLE``) / ``763e6`` = 8.25% of
all tokens should be held as security deposits. It also means that a
delegate should own over 8.25% of the amount of token delegated to them
in order to not miss out on creating any block.

Baking rights
~~~~~~~~~~~~~

Baking in tezos.alpha is the action of signing and publishing a block.
In Bitcoin, the right to publish a block is associated with solving a
proof-of-work puzzle. In tezos.alpha, the right to publish a block in
cycle ``n`` is assigned to a randomly selected roll in a randomly
selected roll snapshot from cycle ``n-ALLOWED_FORK-2``.

We admit, for the time being, that the protocol generates a random seed
for each cycle. From this random seed, we can seed a CSPRNG which is
used to draw baking rights for a cycle.

To each position, or slot, in the cycle, is associated a priority list
of bakers. This is drawn randomly, with replacement, from the set of
active rolls. Each roll is associated with the public key of a delegate,
therefore, for each slot in the cycle, we have an ordered list of public
keys which may create and sign a block. It is possible that the same
public key appears multiple times in this list.

The delegate with the highest priority can bake a block with a timestamp
greater than ``timestamp_of_previous_block`` plus
``TIME_BETWEEN_BLOCKS`` = one minute. The one with the kth highest
priority, ``TIME_BETWEEN_BLOCKS + k * TIME_DELAY_FOR_PRIORITY`` = (1 +
k) minutes.

In future versions, ``TIME_DELAY_FOR_PRIORITY`` may be set to a lower
value than ``TIME_BETWEEN_BLOCKS``.

Baking a block gives a block reward of ``BLOCK_REWARD`` = 16 XTZ plus
all fees paid by transactions inside the block.

Endorsements
~~~~~~~~~~~~

To each baking slot, we associate a list of ``ENDORSERS_PER_BLOCK`` = 32
*endorsers*. Endorsers are drawn from the set of delegates, by randomly
selecting 32 rolls with replacement.

Endorsers receive a reward (at the same time as block creators do). The
reward is ``ENDORSEMENT_REWARD`` = 2 / ``BLOCK_PRIORITY`` where block
priority starts at 1. So the endorsement reward is only half if the
block of priority 2 for a given slot is being endorsed.

Inflation
~~~~~~~~~

Inflation from block rewards and endorsement reward is at most
``ENDORSERS_PER_BLOCK`` \* ``ENDORSEMENT_REWARD`` + ``BLOCK_REWARD`` =
80 XTZ. This means at most 5.51% annual inflation.

Random seed
~~~~~~~~~~~

Cycle ``n`` is associated with a random seed, a 256 bit number generated
at the end of cycle ``(n-ALLOWED_FORK-1)`` using commitments made during
cycle ``(n-ALLOWED_FORK-2)``, in one out of every
``BLOCKS_PER_COMMITMENT`` = 32 blocks.

The commitment must be revealed by the original baker during cycle
``(n-ALLOWED_FORK-1)`` under penalty of forfeiting the rewards and
fees of the block that included the seed commitment (the associated
security deposit is not forfeited).

A *revelation* is an operation, and multiple revelations can thus be
included in a block. The revelations are hashed together to generate a
random seed at the very end of cycle ``(n-ALLOWED_FORK-1)``.

Revelations are free operations which do not compete with transactions
for block space. Up to ``MAX_REVELATIONS_PER_BLOCK`` = 32 revelations
can be contained in any given block. Thus, 1 /
(``MAX_REVELATIONS_PER_BLOCK`` \* ``BLOCKS_PER_COMMITMENT``) = 1/1024 of
the blocks in the cycle are sufficient to include all revelations.

Denunciations
-------------

If two endorsements are made for the same slot or two blocks at the same
height by a delegate, this can be denounced. The denunciation would be
typically be made by the baker, who includes it as a special operation.
In a first time, denunciation will only forfeit the security deposit
for the doubly signed operation. However, over time, as the risk of
accidental double signing becomes small enough, denunciation will
forfeit the entirety of the safety deposits. Half is burned, and half is
added to the block reward.
