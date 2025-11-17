# ImpactDAO

A decentralized impact verification and community contribution platform that enables transparent tracking of social initiatives and compensates contributors through impact tokens.

## Features

- Contributor registration by cause area
- Initiative creation and launch
- Community verification workflow
- Initiative support tracking
- Impact-based rating system
- Community leader status for high-impact contributors

## Getting Started

1. Register as a contributor in your area of impact
2. Launch community initiatives
3. Seek community verification
4. Gather supporter endorsements
5. Receive impact ratings
6. Achieve community leader status

## Smart Contract API

### Contributor Functions
- `register-contributor` - Create contributor profile
- `update-contributor` - Modify profile information
- `launch-initiative` - Start new community initiative
- `verify-initiative` - Verify peer initiative
- `support-initiative` - Endorse verified initiative
- `rate-initiative-impact` - Score initiative effectiveness

### Query Functions
- `get-contributor-profile` - View contributor details
- `get-initiative` - Access initiative information
- `get-total-initiatives` - Get total initiatives count

## Token Economics

- Initiative verification: 8 tokens
- Support action: 13 tokens per level
- Impact scoring: 3 tokens
- High-impact (4+): 45 bonus tokens
- Verified initiative (2+ verifications): 40 tokens

## Validation

Execute `clarinet check` to verify contract compilation.