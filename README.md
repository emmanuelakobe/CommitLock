# CommitLock Smart Contract

A decentralized accountability system built on Stacks blockchain that enables users to stake STX tokens against their commitments.

## Features

- 🔒 **Secure Staking**: Lock STX tokens as commitment collateral
- ✅ **Flexible Check-ins**: Customizable intervals for commitment verification
- 💰 **Automated Rewards**: Earn back stakes upon successful completion
- ⚠️ **Penalty System**: Forfeit stakes for missed commitments
- 🏆 **Achievement Tracking**: Track user streaks and completion rates

## Smart Contract Functions

### Public Functions

#### Create Pledge
```clarity
(create-pledge 
    (description (string-utf8 200))
    (duration uint)
    (interval uint)
    (penalty-address principal)
    (amount uint))
```

#### Check-in
```clarity
(check-in (pledge-id uint))
```

#### End Pledge
```clarity
(end-pledge (pledge-id uint))
```

#### Penalize
```clarity
(penalize (pledge-id uint))
```

### Read-Only Functions

#### Get Pledge
```clarity
(get-pledge (pledge-id uint))
```

#### Get Streak
```clarity
(get-streak (user principal))
```

## Technical Requirements

- Stacks 2.1 or higher
- Clarity SDK
- STX tokens for staking

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Zero STX amount |
| u101 | Not owner |
| u102 | Not active |
| u103 | Invalid check-in window |
| u104 | Already checked in |
| u105 | Pledge not found |
| u106 | Invalid duration |
| u107 | Invalid interval |
| u108 | Too early to end |
| u109 | Insufficient completion |

## Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/CommitLock.git
```

2. Install dependencies
```bash
cd CommitLock
clarinet install
```

## Testing

Run the test suite:
```bash
clarinet test
```

