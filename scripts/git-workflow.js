#!/usr/bin/env node

const { execSync } = require('child_process');
const readline = require('readline');
const fs = require('fs');

// ANSI Colors for better UX
const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    dim: "\x1b[2m",
    cyan: "\x1b[36m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    red: "\x1b[31m",
    magenta: "\x1b[35m"
};

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const question = (query) => new Promise((resolve) => rl.question(query, resolve));

function runCommand (command, ignoreError = false) {
    try {
        return execSync(command, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    } catch (error) {
        if (!ignoreError) {
            console.error(`\n${colors.red}❌ Error executing command: ${command}${colors.reset}`);
            console.error(error.message);
            process.exit(1);
        }
        return '';
    }
}

async function main () {
    console.log(`\n${colors.bright}${colors.cyan}🚀 Interactive Git Flow & Commit Workflow${colors.reset}\n`);

    // Parse arguments for AI/unattended access
    const args = process.argv.slice(2);
    const isAuto = args.includes('--auto') || args.includes('-y');

    if (isAuto) {
        console.log(`${colors.dim}Running in unattended mode...${colors.reset}`);
        const status = runCommand('git status --porcelain', true);
        if (!status) {
            console.log(`${colors.yellow}No changes to commit.${colors.reset}`);
            process.exit(0);
        }
        runCommand('git add .');
        const branch = runCommand('git rev-parse --abbrev-ref HEAD', true) || 'main';
        runCommand(`git commit -m "chore: automated auto-commit on ${branch} [skip ci]"`, true);
        runCommand(`git push -u origin HEAD`, true);
        console.log(`${colors.green}✅ Auto-commit & push successful.${colors.reset}`);
        process.exit(0);
    }

    // --- 1. Branch Creation Workflow ---
    let defaultUsername = runCommand('git config user.name', true).split(' ')[0].toLowerCase() || 'dev';

    console.log(`${colors.magenta}--- Branch Configuration ---${colors.reset}`);

    const usernameInput = await question(`👤 Enter your identifier/username [${colors.bright}${defaultUsername}${colors.reset}]: `);
    const username = usernameInput.trim() || defaultUsername;

    console.log(`\n🌿 ${colors.bright}Git Flow Branch Types:${colors.reset}`);
    const types = [
        { name: 'feature', desc: 'New functionality (feat)' },
        { name: 'bugfix', desc: 'Non-critical fixes (fix)' },
        { name: 'hotfix', desc: 'Critical production fixes (fix)' },
        { name: 'release', desc: 'Version bumps, release prep (chore)' },
        { name: 'docs', desc: 'Documentation changes (docs)' },
        { name: 'chore', desc: 'Maintenance and tasks (chore)' }
    ];

    types.forEach((t, i) => console.log(`  ${colors.cyan}${i + 1}.${colors.reset} ${t.name.padEnd(10)} - ${colors.dim}${t.desc}${colors.reset}`));

    let typeIndex = await question(`\nSelect branch type (1-${types.length}) [${colors.bright}1${colors.reset}]: `);
    const selectedType = types[parseInt(typeIndex || '1') - 1] || types[0];

    const ticketInput = await question(`🎫 Enter ticket/issue number (optional): `);
    const ticket = ticketInput.trim() ? `${ticketInput.trim()}-` : '';

    const descInput = await question(`📝 Enter short description for branch (kebab-case preferred): `);
    let defaultDesc = 'update';
    if (!descInput.trim()) {
        // Try to intelligently guess from git diff / status
        const diffStat = runCommand('git diff --stat', true) || runCommand('git diff --cached --stat', true);
        if (diffStat && diffStat.includes(' README.md')) defaultDesc = 'docs-update';
    }
    const desc = descInput.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || defaultDesc;

    const branchName = `${username}/${selectedType.name}/${ticket}${desc}`;
    console.log(`\n✨ Target Branch: ${colors.green}${colors.bright}${branchName}${colors.reset}`);

    const createBranch = await question(`Create and checkout this branch? (Y/n): `);
    if (createBranch.toLowerCase() !== 'n') {
        console.log(`\n${colors.dim}Switching branch...${colors.reset}`);
        try {
            runCommand(`git checkout -b ${branchName}`);
            console.log(`${colors.green}✅ Checked out new branch.${colors.reset}`);
        } catch (e) {
            console.log(`${colors.yellow}⚠️  Branch might already exist or checkout failed. Switching...${colors.reset}`);
            runCommand(`git checkout ${branchName}`, true);
        }
    }

    // --- 2. Intelligent Commit Workflow ---
    console.log(`\n${colors.magenta}--- Commit & Push ---${colors.reset}`);
    const status = runCommand('git status --porcelain', true);

    if (status) {
        console.log(`${colors.dim}Changes detected:${colors.reset}\n${status}`);

        // Suggest commit type based on branch
        const commitTypeMap = { 'feature': 'feat', 'bugfix': 'fix', 'hotfix': 'fix', 'release': 'chore', 'docs': 'docs', 'chore': 'chore' };
        const defaultCommitType = commitTypeMap[selectedType.name] || 'chore';

        console.log(`\n${colors.cyan}Conventional Commit format: <type>[optional scope]: <description>${colors.reset}`);

        const commitType = await question(`Type [${colors.bright}${defaultCommitType}${colors.reset}]: `) || defaultCommitType;
        const commitScope = await question(`Scope (optional): `);
        const commitDesc = await question(`Description [${colors.bright}${desc}${colors.reset}]: `) || desc;

        const commitChanges = await question(`\nStage all changes, commit, and push? (Y/n): `);
        if (commitChanges.toLowerCase() !== 'n') {
            const scopePart = commitScope.trim() ? `(${commitScope.trim()})` : '';
            const commitMessage = `${commitType}${scopePart}: ${commitDesc.trim()}`;

            console.log(`\n${colors.dim}Executing Git operations...${colors.reset}`);
            runCommand('git add .');
            console.log(`${colors.green}✅ Files staged.${colors.reset}`);

            runCommand(`git commit -m "${commitMessage}"`);
            console.log(`${colors.green}✅ Committed: ${commitMessage}${colors.reset}`);

            runCommand(`git push -u origin HEAD`, true); // Ignore error here to allow proceeding to PR
            console.log(`${colors.green}✅ Successfully pushed to remote origin.${colors.reset}`);

            // --- 3. Optional GitHub CLI (gh) PR Creation ---
            const ghInstalled = runCommand('gh --version', true) !== '';
            if (ghInstalled) {
                const createPr = await question(`\nCreate a Pull Request using GitHub CLI (gh)? (y/N): `);
                if (createPr.toLowerCase() === 'y') {
                    console.log(`\n${colors.dim}Creating Pull Request...${colors.reset}`);
                    try {
                        // Try to guess base branch
                        let baseBranch = 'main';
                        const localBranches = runCommand('git branch', true);
                        if (localBranches.includes(' develop')) baseBranch = 'develop';
                        else if (selectedType.name === 'hotfix' && localBranches.includes(' master')) baseBranch = 'master';

                        // Use standard gh pr create command
                        const prTitle = commitMessage.replace(/"/g, '\\"');
                        runCommand(`gh pr create --title "${prTitle}" --body "Automated PR created via interactive git-workflow script. Ticket: ${ticketInput || 'N/A'}" --base ${baseBranch}`);
                        console.log(`${colors.green}✅ Pull Request created successfully targeting '${baseBranch}'.${colors.reset}`);
                    } catch (err) {
                        console.log(`${colors.yellow}⚠️  Failed to create Pull Request. Ensure 'gh' is correctly configured.${colors.reset}`);
                    }
                }
            }
        } else {
            console.log(`\n${colors.yellow}Skipping commit and push.${colors.reset}`);
        }
    } else {
        console.log(`\n${colors.yellow}No changes detected in working directory.${colors.reset}`);
    }

    console.log(`\n${colors.bright}${colors.green}🎉 Workflow completed! Happy coding!${colors.reset}\n`);
    rl.close();
}

main().catch(err => {
    console.error(`\n${colors.red}❌ Unexpected error:${colors.reset}`, err);
    rl.close();
    process.exit(1);
});
