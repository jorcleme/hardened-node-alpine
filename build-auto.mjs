import { promisify } from 'node:util';
import childProcess from 'node:child_process';
import { Octokit } from 'octokit';
import { config } from 'dotenv';

config({ path: './.env' });

const exec = promisify(childProcess.exec);

const gh = new Octokit({
    auth: process.env.GITHUB_TOKEN
});

const checkForNewerVersion = async () => {
    try {
        const { stdout: versionsOut } = await exec(
            '. ./utils.sh && get_versions',
            { shell: 'bash' }
        );
        const versions = versionsOut.trim().split(' ');
        let latestSupportedVersions = {};

        for (let version of versions) {
            const { stdout } = await exec(`ls ${version}`);
            const { stdout: fullVersionOutput } = await exec(
                `. ./utils.sh && get_full_version ./${version}/${
                    stdout.trim().split('\n')[0]
                }`,
                { shell: 'bash' }
            );
            console.log(`Full version: ${fullVersionOutput}`);
            latestSupportedVersions[version] = {
                fullVersion: fullVersionOutput.trim()
            };
        }

        const { data: availableVersionsJson } = await gh.request(
            'https://nodejs.org/download/release/index.json',
            { headers: { 'x-github-api-version': '2022-11-28' } }
        );
        // filter only more recent versions of availableVersionsJson for each major version in latestSupportedVersions' keys
        // e.g. if latestSupportedVersions = { "12": "12.22.10", "14": "14.19.0", "16": "16.14.0", "17": "17.5.0" }
        // and availableVersions = ["Node.js 12.22.10", "Node.js 12.24.0", "Node.js 14.19.0", "Node.js 14.22.0", "Node.js 16.14.0", "Node.js 16.16.0", "Node.js 17.5.0", "Node.js 17.8.0"]
        // return { "12": "12.24.0", "14": "14.22.0", "16": "16.16.0", "17": "17.8.0" }

        let filteredNewerVersions = {};

        for (let availableVersion of availableVersionsJson) {
            const [availableMajor, availableMinor, availablePatch] =
                availableVersion.version.split('v')[1].split('.');
            if (latestSupportedVersions[availableMajor] == null) {
                continue;
            }
            const [_latestMajor, latestMinor, latestPatch] =
                latestSupportedVersions[availableMajor].fullVersion.split('.');

            if (
                latestSupportedVersions[availableMajor] &&
                (Number(availableMinor) > Number(latestMinor) ||
                    (availableMinor === latestMinor &&
                        Number(availablePatch) > Number(latestPatch)))
            ) {
                filteredNewerVersions[availableMajor] = {
                    fullVersion: `${availableMajor}.${availableMinor}.${availablePatch}`
                };
            }
        }

        return {
            shouldUpdate:
                Object.keys(filteredNewerVersions).length > 0 &&
                JSON.stringify(filteredNewerVersions) !==
                    JSON.stringify(latestSupportedVersions),
            versions: filteredNewerVersions
        };
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
};

// a function that queries the Node.js unofficial release website for new musl versions and security releases,
// and returns relevant information
const checkForMuslVersionsAndSecurityReleases = async (versions) => {
    try {
        const { data: unofficialBuildsIndexText } = await gh.request(
            'https://unofficial-builds.nodejs.org/download/release/index.json'
        );

        for (let version of Object.keys(versions)) {
            const buildVersion = unofficialBuildsIndexText.find(
                (indexVersion) =>
                    indexVersion.version === `v${versions[version].fullVersion}`
            );

            versions[version].muslBuildExists =
                buildVersion?.files.includes('linux-x64-musl') ?? false;
            versions[version].isSecurityRelease =
                buildVersion?.security ?? false;
        }
        return versions;
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
};

export default async function () {
    const { shouldUpdate, versions } = await checkForNewerVersion();

    if (!shouldUpdate) {
        console.log('No new versions found. No update required.');
        process.exit(0);
    } else {
        const newVersions = await checkForMuslVersionsAndSecurityReleases(
            versions
        );
        let updatedVersions = [];
        for (let version of Object.keys(newVersions)) {
            if (newVersions[version].muslBuildExists) {
                const { stdout } = await exec(
                    `./update.sh ${
                        newVersions[version].isSecurityRelease ? '-s ' : ''
                    }${version}`
                );
                console.log(stdout);
                updatedVersions.push(newVersions[version].fullVersion);
            } else {
                console.log(
                    `There's no musl build for version ${newVersions[version].fullVersion} yet.`
                );
                process.exit(0);
            }
        }
        const { stdout } = await exec(`git diff`);
        console.log(stdout);

        return updatedVersions.join(', ');
    }
}
