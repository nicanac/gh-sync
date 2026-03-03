const fs = require('fs');
const path = require('path');

function loadEnv() {
    const envPaths = [
        path.join(__dirname, '..', '..', '.env'),
        path.join(__dirname, '..', '.env'),
        path.join(__dirname, '.env')
    ];
    for (const envPath of envPaths) {
        if (fs.existsSync(envPath)) {
            const content = fs.readFileSync(envPath, 'utf8');
            for (const line of content.split(/\r?\n/)) {
                const trimmed = line.trim();
                if (!trimmed || trimmed.startsWith('#')) continue;
                const eqIdx = trimmed.indexOf('=');
                if (eqIdx > 0) {
                    const key = trimmed.slice(0, eqIdx).trim();
                    let val = trimmed.slice(eqIdx + 1).trim();
                    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
                        val = val.slice(1, -1);
                    }
                    if (!process.env[key]) {
                        process.env[key] = val;
                    }
                }
            }
            break;
        }
    }
}
loadEnv();

const NOTION_TOKEN = process.env.NOTION_TOKEN || process.env.NOTION_API_KEY || '';
const DATABASE_ID = process.env.NOTION_DATABASE_ID || '7309555c677983b898810171663211f0';

const BASE_DIR = path.join(__dirname, '..');
const SCAN_DIRS = ['.agent', '.agents', '.claude', '.github'];

async function request (method, endpoint, body = null) {
    const options = {
        method,
        headers: {
            'Authorization': `Bearer ${NOTION_TOKEN}`,
            'Notion-Version': '2022-06-28',
            'Content-Type': 'application/json'
        }
    };
    if (body) {
        options.body = JSON.stringify(body);
    }
    const res = await fetch(`https://api.notion.com/v1${endpoint}`, options);
    if (!res.ok) {
        const text = await res.text();
        throw new Error(`Notion API Error (${res.status}): ${text}`);
    }
    return res.json();
}

async function getNotionAgents () {
    console.log('Fetching agents from Notion...');
    const data = await request('POST', `/databases/${DATABASE_ID}/query`);
    return data.results.map(row => {
        const props = row.properties;
        const name = props['Agent Name']?.title?.[0]?.plain_text || 'Unnamed';
        const purpose = props['Purpose']?.rich_text?.[0]?.plain_text || '';
        const triggerTypes = (props['Trigger Type']?.multi_select || []).map(s => s.name);
        return {
            id: row.id,
            name,
            purpose,
            triggerTypes,
            url: props['Agent URL']?.url || ''
        };
    });
}

async function addAgentToNotion (agent) {
    console.log(`Adding ${agent.name} to Notion...`);
    const body = {
        parent: { database_id: DATABASE_ID },
        properties: {
            'Agent Name': { title: [{ text: { content: agent.name } }] }
        }
    };
    if (agent.description) {
        body.properties['Purpose'] = { rich_text: [{ text: { content: agent.description } }] };
    }
    await request('POST', '/pages', body);
}

function parseFrontmatter (content) {
    const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!match) return null;
    const yaml = match[1];
    const data = {};
    yaml.split(/\r?\n/).forEach(line => {
        const idx = line.indexOf(':');
        if (idx > 0) {
            const key = line.slice(0, idx).trim();
            let value = line.slice(idx + 1).trim();
            // remove surrounding quotes
            if ((value.startsWith("'") && value.endsWith("'")) ||
                (value.startsWith('"') && value.endsWith('"'))) {
                value = value.slice(1, -1);
            }
            data[key] = value;
        }
    });
    return data;
}

function scanLocalAgents (dir) {
    let agents = [];
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            agents = agents.concat(scanLocalAgents(fullPath));
        } else if (fullPath.endsWith('.md')) {
            const content = fs.readFileSync(fullPath, 'utf8');
            const data = parseFrontmatter(content);
            if (data && data.name) {
                agents.push({
                    name: data.name,
                    description: data.description || '',
                    path: fullPath
                });
            }
        }
    }
    return agents;
}

function toKebabCase (str) {
    return str.replace(/([a-z])([A-Z])/g, '$1-$2').replace(/[\s_]+/g, '-').toLowerCase();
}

function placeAgentLocally (agent) {
    const isManual = agent.triggerTypes.includes('Manual Only');
    const slug = toKebabCase(agent.name);
    let targetPath;

    if (isManual || slug.includes('skill')) {
        targetPath = path.join(BASE_DIR, '.agents', 'skills', slug, 'SKILL.md');
    } else if (slug.includes('rule')) {
        targetPath = path.join(BASE_DIR, '.agents', 'rules', `${slug}.md`);
    } else {
        targetPath = path.join(BASE_DIR, '.agents', 'workflows', `${slug}.md`);
    }

    console.log(`Creating local agent: ${agent.name} at ${targetPath}`);
    const dir = path.dirname(targetPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const safePurpose = agent.purpose.replace(/"/g, '\\"').replace(/\n/g, ' ');
    const content = `---
name: "${agent.name}"
description: "${safePurpose}"
---

# ${agent.name}

${agent.purpose}
`;
    fs.writeFileSync(targetPath, content);
}

async function sync () {
    console.log('--- Notion Git Agent Sync ---');
    try {
        const notionAgents = await getNotionAgents();
        const localAgents = [];

        console.log('Scanning local files...');
        for (const d of SCAN_DIRS) {
            const p = path.join(BASE_DIR, d);
            if (fs.existsSync(p)) {
                localAgents.push(...scanLocalAgents(p));
            }
        }

        const notionMap = new Map(notionAgents.map(a => [a.name.toLowerCase(), a]));
        const localMap = new Map(localAgents.map(a => [a.name.toLowerCase(), a]));

        let pullCount = 0;
        let pushCount = 0;

        // 1. Notion -> Local
        for (const na of notionAgents) {
            const lowerName = na.name.toLowerCase();
            if (!localMap.has(lowerName)) {
                placeAgentLocally(na);
                pullCount++;
            }
        }

        // 2. Local -> Notion
        for (const la of localAgents) {
            const lowerName = la.name.toLowerCase();
            if (!notionMap.has(lowerName)) {
                await addAgentToNotion(la);
                pushCount++;
            }
        }

        console.log(`Sync complete! Pulled ${pullCount} from Notion. Pushed ${pushCount} to Notion.`);
    } catch (err) {
        console.error('Failed to sync:', err);
    }
}

sync();
