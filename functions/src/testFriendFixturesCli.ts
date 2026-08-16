import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  App,
  applicationDefault,
  deleteApp,
  initializeApp,
} from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  FixtureCommand,
  FixtureOperationSummary,
  FixtureToolError,
  cleanupTestFriendFixtures,
  refreshTestFriendLocations,
  seedTestFriendFixtures,
} from "./testFriendFixtures.js";

export interface FixtureCLIOptions {
  command: FixtureCommand;
  projectID: string;
  ownerUID: string;
  acceptedCount: number;
  pendingCount: number;
  locationPreset: "seoul";
  apply: boolean;
  allowNotifications: boolean;
  help: boolean;
}

export function parseFixtureCLIArguments(argv: readonly string[]): FixtureCLIOptions {
  const command = argv[0];
  if (command !== "seed" && command !== "refresh" && command !== "cleanup") {
    throw new FixtureToolError(
      "La commande doit être seed, refresh ou cleanup.",
    );
  }

  const values = new Map<string, string>();
  const flags = new Set<string>();
  const valueArguments = new Set([
    "--project",
    "--owner-uid",
    "--accepted",
    "--pending",
    "--location-preset",
  ]);
  const flagArguments = new Set([
    "--apply",
    "--allow-notifications",
    "--help",
  ]);

  for (let index = 1; index < argv.length; index += 1) {
    const argument = argv[index];
    if (!argument || (!valueArguments.has(argument) && !flagArguments.has(argument))) {
      throw new FixtureToolError("Un argument de la commande est inconnu.");
    }
    if (values.has(argument) || flags.has(argument)) {
      throw new FixtureToolError("Un argument de la commande est répété.");
    }
    if (flagArguments.has(argument)) {
      flags.add(argument);
      continue;
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) {
      throw new FixtureToolError("Une valeur d’argument est manquante.");
    }
    values.set(argument, value);
    index += 1;
  }

  const help = flags.has("--help");
  const projectID = values.get("--project") ?? "";
  const ownerUID = values.get("--owner-uid") ?? "";
  if (!help && (!projectID || !ownerUID)) {
    throw new FixtureToolError(
      "--project et --owner-uid sont obligatoires.",
    );
  }

  const acceptedCount = integerArgument(values.get("--accepted"), 8);
  const pendingCount = integerArgument(values.get("--pending"), 0);
  const locationPreset = values.get("--location-preset") ?? "seoul";
  if (locationPreset !== "seoul") {
    throw new FixtureToolError("Seul --location-preset seoul est disponible.");
  }
  if (command !== "seed" && (
    values.has("--accepted") ||
    values.has("--pending") ||
    flags.has("--allow-notifications")
  )) {
    throw new FixtureToolError(
      "Les quantités et notifications sont réservées à la commande seed.",
    );
  }

  return {
    command,
    projectID,
    ownerUID,
    acceptedCount,
    pendingCount,
    locationPreset,
    apply: flags.has("--apply"),
    allowNotifications: flags.has("--allow-notifications"),
    help,
  };
}

async function run(): Promise<void> {
  let app: App | undefined;
  try {
    const options = parseFixtureCLIArguments(process.argv.slice(2));
    if (options.help) {
      process.stdout.write(helpText(options.command));
      return;
    }

    const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
    if (emulatorHost && !process.env.METADATA_SERVER_DETECTION) {
      process.env.METADATA_SERVER_DETECTION = "none";
    }
    app = emulatorHost
      ? initializeApp(
        {
          credential: applicationDefault(),
          projectId: options.projectID,
        },
        fixtureAppName(),
      )
      : initializeApp(
        {
          credential: applicationDefault(),
          projectId: options.projectID,
        },
        fixtureAppName(),
      );
    const database = getFirestore(app);
    let summary: FixtureOperationSummary;
    switch (options.command) {
    case "seed":
      summary = await seedTestFriendFixtures(database, {
        projectID: options.projectID,
        ownerUID: options.ownerUID,
        acceptedCount: options.acceptedCount,
        pendingCount: options.pendingCount,
        locationPreset: options.locationPreset,
        apply: options.apply,
        allowNotifications: options.allowNotifications,
        isEmulator: Boolean(emulatorHost),
      });
      break;
    case "refresh":
      summary = await refreshTestFriendLocations(database, {
        projectID: options.projectID,
        ownerUID: options.ownerUID,
        apply: options.apply,
      });
      break;
    case "cleanup":
      summary = await cleanupTestFriendFixtures(database, {
        projectID: options.projectID,
        ownerUID: options.ownerUID,
        apply: options.apply,
      });
      break;
    }
    process.stdout.write(summaryText(summary, options.apply));
  } catch (error) {
    const message = error instanceof FixtureToolError
      ? error.message
      : "Une erreur inattendue a interrompu l’outil.";
    process.stderr.write(`Erreur : ${message}\n`);
    process.exitCode = 1;
  } finally {
    if (app) {
      await deleteApp(app);
    }
  }
}

function summaryText(
  summary: FixtureOperationSummary,
  apply: boolean,
): string {
  const mode = apply ? "application" : "simulation";
  return [
    `Mode : ${mode}`,
    `Résultat : ${summary.outcome}`,
    `Profils fictifs : ${summary.fixtureCount}`,
    `Relations acceptées : ${summary.acceptedCount}`,
    `Demandes entrantes : ${summary.pendingCount}`,
    `Positions à Séoul : ${summary.locationCount}`,
    `Documents concernés : ${summary.documentCount}`,
    apply ? "" : "Aucune écriture effectuée. Ajoute --apply pour appliquer.",
    "",
  ].join("\n");
}

function helpText(command: FixtureCommand): string {
  const commandOptions = command === "seed"
    ? "  --accepted <nombre>       Relations acceptées (8 par défaut)\n" +
      "  --pending <nombre>        Demandes entrantes (0 par défaut)\n" +
      "  --allow-notifications     Autorise les notifications des demandes\n"
    : "";
  return [
    `Commande : ${command}`,
    "",
    "Options obligatoires :",
    "  --project <projet>         Projet Firebase explicite",
    "  --owner-uid <uid>          UID Firebase du vrai profil Wander",
    "",
    "Options :",
    commandOptions.trimEnd(),
    "  --location-preset seoul   Positions sur des lieux publics à Séoul",
    "  --apply                    Effectue les mutations",
    "  --help                     Affiche cette aide",
    "",
    "Sans --apply, la commande reste en lecture seule.",
    "Les credentials Firebase Admin doivent rester hors du dépôt.",
    "",
  ].filter((line) => line !== "").join("\n") + "\n";
}

function integerArgument(value: string | undefined, fallback: number): number {
  if (value === undefined) {
    return fallback;
  }
  if (!/^(0|[1-9][0-9]*)$/.test(value)) {
    throw new FixtureToolError("Une quantité doit être un entier positif.");
  }
  return Number(value);
}

function fixtureAppName(): string {
  return `test-friend-fixtures-${process.pid}-${Date.now()}`;
}

const entryPath = process.argv[1] ? resolve(process.argv[1]) : null;
if (entryPath && fileURLToPath(import.meta.url) === entryPath) {
  await run();
}
