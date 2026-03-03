#!/usr/bin/env node

/**
 * Git Workflow Automation Script
 * 
 * Aligns with the skills:
 * - git-flow-branch-creator
 * - git-commit (Conventional Commits)
 * - gh-cli
 * 
 * Usage:
 *   node scripts/git-workflow.js [options]
 * 
 * Interactive mode runs automatically if no options are provided.
 */

const { execSync } = require('child_process');
const readline = require('readline');

function run(cmd) {
    try {
        return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    } catch (e) {
        if (e.stderr) {
            console.error(e.stderr.toString());
        }
        throw new Error(`Command failed: ${cmd}`);
    }
}

function runInherit(cmd) {
    try {
        execSync(cmd, { stdio: 'inherit' });
    } catch (e) {
        throw new Error(`Command failed: ${cmd}`);
    }
}

async function main() {
    const args = process.argv.slice(2);
    const parsed = {
        type: '',
        ticket: '',
        desc: '',
        scope: '',
        message: '',
        unattended: false
    };

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--type' || args[i] === '-t') parsed.type = args[++i];
        else if (args[i] === '--ticket' || args[i] === '-k') parsed.ticket = args[++i];
        else if (args[i] === '--desc' || args[i] === '-d') parsed.desc = args[++i];
        else if (args[i] === '--scope' || args[i] === '-s') parsed.scope = args[++i];
        else if (args[i] === '--message' || args[i] === '-m') parsed.message = args[++i];
        else if (args[i] === '--unattended' || args[i] === '-y') parsed.unattended = true;
    }

    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const question = (query) => new Promise(resolve => rl.question(query, resolve));

    try {
        console.log("=== AI-Assisted Git Workflow Automation ===\n");

        if (!parsed.type && !parsed.unattended) {
            console.log("Common Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, release, hotfix");
            parsed.type = (await question("Type of change (default: feat): ")) || "feat";
        } else if (!parsed.type) {
            parsed.type = "feat";
        }

        if (parsed.ticket === '' && !parsed.unattended) {
            parsed.ticket = await question("Ticket number (optional, e.g., PROJ-123): ");
        }

        if (!parsed.desc && !parsed.unattended) {
            parsed.desc = await question("Short description (e.g., add login endpoint): ");
        }
        
        if (!parsed.desc) {
            throw new Error("Description is required to form a branch name!");
        }

        if (parsed.scope === '' && !parsed.unattended) {
            parsed.scope = await question("Commit scope (optional, e.g., ui, auth): ");
        }

        rl.close();

        // 1. Resolve Username for branch prefix
        let username = 'user';
        try {
            // Priority 1: User email prefix from git
            const email = run('git config user.email');
            if (email) {
                username = email.split('@')[0].replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
            }
        } catch(e) {
            try {
                // Priority 2: OS Username
                username = require('os').userInfo().username.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
            } catch(ex) {}
        }

        // 2. Format semantic branch name: username/type/[ticket-]description
        const safeDesc = parsed.desc.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
        const ticketPart = parsed.ticket ? `${parsed.ticket.toUpperCase()}-` : '';
        const branchName = `${username}/${parsed.type}/${ticketPart}${safeDesc}`;

        console.log(`\n> Analyzing branch setup: ${branchName}`);
        
        // Checkout or create branch
        try {
            const currentBranch = run('git branch --show-current');
            if (currentBranch !== branchName) {
                console.log(`> Checking out new branch: ${branchName}`);
                runInherit(`git checkout -b ${branchName}`);
            } else {
                console.log(`> Already on branch: ${branchName}`);
            }
        } catch (e) {
            // If checking out existing branch fails, create it
            console.log(`> Creating and checking out branch: ${branchName}`);
            runInherit(`git checkout -b ${branchName}`);
        }

        // 3. Stage changes automatically if nothing is explicitly staged
        let status = run('git status --porcelain');
        if (!status) {
            console.log("\n> No changes detected in the working tree. Branch created.");
            return;
        }

        const staged = run('git diff --staged --name-only');
        if (!staged) {
            console.log("\n> Intelligent Staging: Adding all modified files...");
            runInherit('git add .');
        } else {
            console.log("\n> Found pre-staged changes, respecting staging choices and skipping 'git add .'");
        }

        // 4. Generate Semantic Commit
        const scopePart = parsed.scope ? `(${parsed.scope})` : '';
        const defaultMessage = `${parsed.type}${scopePart}: ${parsed.desc}`;
        const commitMsg = parsed.message || defaultMessage;

        console.log(`\n> Creating Conventional Commit...`);
        console.log(`Message: "${commitMsg}"`);
        runInherit(`git commit -m "${commitMsg}"`);

        // 5. Push to Remote Tracking
        console.log(`\n> Pushing to origin...`);
        runInherit(`git push -u origin ${branchName}`);

        console.log("\n=== Operation Successful! ===");
        console.log(`Branch: ${branchName}`);
        console.log("You can now open a PR directly using GitHub CLI: `gh pr create`");

    } catch (err) {
        if (!rl.closed) rl.close();
        console.error("\n[ERROR]", err.message);
        process.exit(1);
    }
}

main();
