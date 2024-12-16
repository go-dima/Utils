Here's how to set up multiple GitHub accounts using SSH config:

1. First create SSH keys for both accounts:
```bash
ssh-keygen -t ed25519 -C "email1@example.com" -f ~/.ssh/github-account1
ssh-keygen -t ed25519 -C "email2@example.com" -f ~/.ssh/github-account2
```

2. Create/edit ~/.ssh/config file with this configuration:
```
# First GitHub account
Host github.com-account1
   HostName github.com
   User git
   IdentityFile ~/.ssh/github-account1
   IdentitiesOnly yes

# Second GitHub account
Host github.com-account2
   HostName github.com
   User git
   IdentityFile ~/.ssh/github-account2
   IdentitiesOnly yes
```

3. Add SSH keys to respective GitHub accounts:
```bash
# Copy public keys
cat ~/.ssh/github-account1.pub
cat ~/.ssh/github-account2.pub
```
Then paste them in GitHub Settings > SSH Keys

4. When cloning repositories, use the Host from config:
```bash
# For account1
git clone git@github.com-account1:username/repo.git

# For account2
git clone git@github.com-account2:username/repo.git
```

5. Set local git config for each repository:
```bash
git config user.email "email1@example.com"  # for repos under account1
git config user.email "email2@example.com"  # for repos under account2
```
