import { createHash } from "node:crypto";
import {
  DocumentData,
  DocumentReference,
  Firestore,
  GeoPoint,
  Timestamp,
} from "firebase-admin/firestore";

const manifestCollection = "_testFriendFixtures";
const manifestKind = "wander-test-friends";
const manifestSchemaVersion = 1;
const maximumFixtureCount = 50;
const maximumNotificationDeviceTargets = 500;
const writeBatchSize = 400;
const friendCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const fixtureNames = [
  "Min-jun (test)",
  "Seo-yeon (test)",
  "Ji-hoon (test)",
  "Ha-eun (test)",
  "Do-yun (test)",
  "Ji-woo (test)",
  "Hyun-woo (test)",
  "Soo-ah (test)",
  "Jun-seo (test)",
  "Ye-rin (test)",
] as const;
const avatarIDs = [
  "cyclops-horns",
  "cyclops-crown",
  "radiant-eye",
  "radar-face",
  "star-eye",
  "skull",
  "wave-hair",
  "flame-hair",
  "labyrinth",
  "locator-hair",
  "social-rays",
  "antenna-hair",
] as const;
const profileColors = [
  "#007AFF",
  "#34C759",
  "#FF9500",
  "#AF52DE",
  "#FF2D55",
  "#5AC8FA",
  "#FF3B30",
  "#5856D6",
  "#00A896",
  "#C77800",
] as const;

export type FixtureStatus = "accepted" | "pending";
export type LocationPreset = "seoul";
export type FixtureCommand = "seed" | "refresh" | "cleanup";

export interface FixturePlanInput {
  projectID: string;
  ownerUID: string;
  acceptedCount: number;
  pendingCount: number;
  locationPreset: LocationPreset;
  now?: Date;
}

export interface FixtureLocation {
  latitude: number;
  longitude: number;
  horizontalAccuracy: number;
  spotEnteredAt: Date;
  landmark: string;
}

export interface TestFriendFixture {
  index: number;
  userID: string;
  friendCode: string;
  friendshipID: string;
  displayName: string;
  avatarID: string;
  profileColorHex: string;
  status: FixtureStatus;
  location: FixtureLocation;
}

export interface FixturePlan {
  projectID: string;
  ownerUID: string;
  ownerHash: string;
  manifestID: string;
  configurationHash: string;
  acceptedCount: number;
  pendingCount: number;
  locationPreset: LocationPreset;
  createdAt: Date;
  fixtures: TestFriendFixture[];
}

interface StoredFixtureEntry {
  index: number;
  userID: string;
  friendCode: string;
  friendshipID: string;
  status: FixtureStatus;
}

export interface FixtureManifest {
  schemaVersion: number;
  kind: string;
  projectID: string;
  ownerHash: string;
  configurationHash: string;
  acceptedCount: number;
  pendingCount: number;
  locationPreset: LocationPreset;
  createdAt: Timestamp;
  locationRefreshedAt: Timestamp;
  updatedAt: Timestamp;
  fixtures: StoredFixtureEntry[];
}

export interface SeedOptions extends FixturePlanInput {
  apply: boolean;
  allowNotifications: boolean;
  isEmulator?: boolean;
}

export interface FixtureOwnerOptions {
  projectID: string;
  ownerUID: string;
  apply: boolean;
  now?: Date;
}

export interface FixtureOperationSummary {
  command: FixtureCommand;
  outcome:
    | "would-create"
    | "created"
    | "already-present"
    | "would-refresh"
    | "refreshed"
    | "would-clean"
    | "cleaned"
    | "nothing-to-clean";
  fixtureCount: number;
  acceptedCount: number;
  pendingCount: number;
  locationCount: number;
  documentCount: number;
}

interface SeoulLocation {
  landmark: string;
  latitude: number;
  longitude: number;
}

const seoulLocations: readonly SeoulLocation[] = [
  {
    landmark: "Hôtel de ville de Séoul",
    latitude: 37.5663,
    longitude: 126.9779,
  },
  {
    landmark: "Gyeongbokgung",
    latitude: 37.5796,
    longitude: 126.9770,
  },
  {
    landmark: "Namsan Seoul Tower",
    latitude: 37.5512,
    longitude: 126.9882,
  },
  {
    landmark: "Hongdae",
    latitude: 37.5563,
    longitude: 126.9236,
  },
  {
    landmark: "Gangnam Station",
    latitude: 37.4979,
    longitude: 127.0276,
  },
  {
    landmark: "Lotte World Tower",
    latitude: 37.5131,
    longitude: 127.1025,
  },
  {
    landmark: "Dongdaemun Design Plaza",
    latitude: 37.5665,
    longitude: 127.0092,
  },
  {
    landmark: "Bukchon Hanok Village",
    latitude: 37.5826,
    longitude: 126.9831,
  },
  {
    landmark: "Seoul Forest",
    latitude: 37.5444,
    longitude: 127.0374,
  },
  {
    landmark: "Yeouido Hangang Park",
    latitude: 37.5284,
    longitude: 126.9345,
  },
] as const;

export class FixtureToolError extends Error {
  override name = "FixtureToolError";
}

export function buildFixturePlan(input: FixturePlanInput): FixturePlan {
  validateProjectID(input.projectID);
  validateOwnerUID(input.ownerUID);
  validateCounts(input.acceptedCount, input.pendingCount);
  if (input.locationPreset !== "seoul") {
    throw new FixtureToolError("Le préréglage de position est invalide.");
  }

  const createdAt = input.now ? new Date(input.now) : new Date();
  if (Number.isNaN(createdAt.getTime())) {
    throw new FixtureToolError("La date de génération est invalide.");
  }

  const ownerHash = hashText(input.ownerUID).slice(0, 12);
  const fixtureCount = input.acceptedCount + input.pendingCount;
  const configurationHash = hashText(JSON.stringify({
    ownerHash,
    projectID: input.projectID,
    acceptedCount: input.acceptedCount,
    pendingCount: input.pendingCount,
    locationPreset: input.locationPreset,
  })).slice(0, 16);
  const fixtures = Array.from({ length: fixtureCount }, (_, index) => {
    const userID = `wander-test-${ownerHash}-${String(index + 1).padStart(2, "0")}`;
    const participants = [input.ownerUID, userID].sort();
    const status: FixtureStatus = index < input.acceptedCount
      ? "accepted"
      : "pending";
    return {
      index,
      userID,
      friendCode: deterministicFriendCode(input.ownerUID, index),
      friendshipID: participants.join("__"),
      displayName: fixtureDisplayName(index),
      avatarID: avatarIDs[index % avatarIDs.length] ?? avatarIDs[0],
      profileColorHex:
        profileColors[index % profileColors.length] ?? profileColors[0],
      status,
      location: seoulLocation(input.ownerUID, index, createdAt),
    };
  });

  return {
    projectID: input.projectID,
    ownerUID: input.ownerUID,
    ownerHash,
    manifestID: `owner-${ownerHash}`,
    configurationHash,
    acceptedCount: input.acceptedCount,
    pendingCount: input.pendingCount,
    locationPreset: input.locationPreset,
    createdAt,
    fixtures,
  };
}

export function buildManifestData(
  plan: FixturePlan,
  timestamp = Timestamp.fromDate(plan.createdAt),
): FixtureManifest {
  return {
    schemaVersion: manifestSchemaVersion,
    kind: manifestKind,
    projectID: plan.projectID,
    ownerHash: plan.ownerHash,
    configurationHash: plan.configurationHash,
    acceptedCount: plan.acceptedCount,
    pendingCount: plan.pendingCount,
    locationPreset: plan.locationPreset,
    createdAt: timestamp,
    locationRefreshedAt: timestamp,
    updatedAt: timestamp,
    fixtures: plan.fixtures.map((fixture) => ({
      index: fixture.index,
      userID: fixture.userID,
      friendCode: fixture.friendCode,
      friendshipID: fixture.friendshipID,
      status: fixture.status,
    })),
  };
}

export function parseFixtureManifest(
  data: unknown,
  projectID: string,
  ownerUID: string,
): { manifest: FixtureManifest; plan: FixturePlan } {
  validateProjectID(projectID);
  validateOwnerUID(ownerUID);
  if (!isRecord(data)) {
    throw invalidManifestError();
  }

  const acceptedCount = data.acceptedCount;
  const pendingCount = data.pendingCount;
  const locationPreset = data.locationPreset;
  const createdAt = data.createdAt;
  if (
    data.schemaVersion !== manifestSchemaVersion ||
    data.kind !== manifestKind ||
    data.projectID !== projectID ||
    typeof acceptedCount !== "number" ||
    typeof pendingCount !== "number" ||
    locationPreset !== "seoul" ||
    !(createdAt instanceof Timestamp) ||
    !(data.locationRefreshedAt instanceof Timestamp) ||
    !(data.updatedAt instanceof Timestamp) ||
    !Array.isArray(data.fixtures)
  ) {
    throw invalidManifestError();
  }

  const plan = buildFixturePlan({
    projectID,
    ownerUID,
    acceptedCount,
    pendingCount,
    locationPreset,
    now: createdAt.toDate(),
  });
  if (
    data.ownerHash !== plan.ownerHash ||
    data.configurationHash !== plan.configurationHash ||
    data.fixtures.length !== plan.fixtures.length
  ) {
    throw invalidManifestError();
  }

  const fixtures = data.fixtures.map((candidate, index) => {
    if (!isRecord(candidate)) {
      throw invalidManifestError();
    }
    const expected = plan.fixtures[index];
    if (
      !expected ||
      candidate.index !== expected.index ||
      candidate.userID !== expected.userID ||
      candidate.friendCode !== expected.friendCode ||
      candidate.friendshipID !== expected.friendshipID ||
      candidate.status !== expected.status
    ) {
      throw invalidManifestError();
    }
    return {
      index: expected.index,
      userID: expected.userID,
      friendCode: expected.friendCode,
      friendshipID: expected.friendshipID,
      status: expected.status,
    };
  });

  return {
    manifest: {
      schemaVersion: manifestSchemaVersion,
      kind: manifestKind,
      projectID,
      ownerHash: plan.ownerHash,
      configurationHash: plan.configurationHash,
      acceptedCount,
      pendingCount,
      locationPreset,
      createdAt,
      locationRefreshedAt: data.locationRefreshedAt,
      updatedAt: data.updatedAt,
      fixtures,
    },
    plan,
  };
}

export function fixtureTargetPaths(plan: FixturePlan): string[] {
  return plan.fixtures.flatMap((fixture) => [
    `users/${fixture.userID}`,
    `friendCodes/${fixture.friendCode}`,
    `friendships/${fixture.friendshipID}`,
    `locations/${fixture.userID}`,
  ]);
}

export function notificationDispatchID(
  friendshipID: string,
  createdAt: Timestamp,
): string {
  return `friendRequest__${friendshipID}__${createdAt.seconds}_${createdAt.nanoseconds}`;
}

export async function seedTestFriendFixtures(
  database: Firestore,
  options: SeedOptions,
): Promise<FixtureOperationSummary> {
  const plan = buildFixturePlan(options);
  if (
    options.apply &&
    plan.pendingCount > 0 &&
    !options.allowNotifications &&
    !options.isEmulator
  ) {
    throw new FixtureToolError(
      "Les demandes entrantes peuvent déclencher des notifications. " +
        "Ajoute --allow-notifications pour les autoriser.",
    );
  }

  const ownerSnapshot = await safeFirebaseCall(
    () => database.collection("users").doc(options.ownerUID).get(),
  );
  if (!ownerSnapshot.exists) {
    throw new FixtureToolError(
      "Le profil propriétaire est introuvable dans le projet demandé.",
    );
  }

  const manifestReference = fixtureManifestReference(database, plan.manifestID);
  const manifestSnapshot = await safeFirebaseCall(() => manifestReference.get());
  if (manifestSnapshot.exists) {
    const existing = parseFixtureManifest(
      manifestSnapshot.data(),
      options.projectID,
      options.ownerUID,
    );
    if (existing.plan.configurationHash !== plan.configurationHash) {
      throw new FixtureToolError(
        "Des fixtures existent déjà avec une autre configuration. " +
          "Nettoie-les avant de changer les quantités.",
      );
    }
    return operationSummary("seed", "already-present", existing.plan, 0);
  }

  const writes = fixtureWrites(plan);
  const references = writes.map((write) => database.doc(write.path));
  const snapshots = await safeFirebaseCall(() => database.getAll(...references));
  const collisionCount = snapshots.filter((snapshot) => snapshot.exists).length;
  if (collisionCount > 0) {
    throw new FixtureToolError(
      "Une ou plusieurs cibles existent sans manifeste valide. " +
        "Aucune écriture n’a été effectuée.",
    );
  }

  if (!options.apply) {
    return operationSummary("seed", "would-create", plan, writes.length + 1);
  }

  const timestamp = Timestamp.fromDate(plan.createdAt);
  const batch = database.batch();
  for (const write of writes) {
    batch.create(database.doc(write.path), write.data);
  }
  batch.create(manifestReference, buildManifestData(plan, timestamp));
  await safeFirebaseCall(() => batch.commit());
  return operationSummary("seed", "created", plan, writes.length + 1);
}

export async function refreshTestFriendLocations(
  database: Firestore,
  options: FixtureOwnerOptions,
): Promise<FixtureOperationSummary> {
  validateProjectID(options.projectID);
  validateOwnerUID(options.ownerUID);
  const ownerHash = hashText(options.ownerUID).slice(0, 12);
  const manifestReference = fixtureManifestReference(
    database,
    `owner-${ownerHash}`,
  );
  const [ownerSnapshot, manifestSnapshot] = await safeFirebaseCall(() =>
    Promise.all([
      database.collection("users").doc(options.ownerUID).get(),
      manifestReference.get(),
    ])
  );
  if (!ownerSnapshot.exists) {
    throw new FixtureToolError(
      "Le profil propriétaire est introuvable dans le projet demandé.",
    );
  }
  if (!manifestSnapshot.exists) {
    throw new FixtureToolError(
      "Aucun manifeste de fixtures n’existe pour ce profil.",
    );
  }

  const parsed = parseFixtureManifest(
    manifestSnapshot.data(),
    options.projectID,
    options.ownerUID,
  );
  const refreshedPlan = buildFixturePlan({
    projectID: options.projectID,
    ownerUID: options.ownerUID,
    acceptedCount: parsed.plan.acceptedCount,
    pendingCount: parsed.plan.pendingCount,
    locationPreset: parsed.plan.locationPreset,
    now: options.now,
  });
  if (!options.apply) {
    return operationSummary(
      "refresh",
      "would-refresh",
      refreshedPlan,
      refreshedPlan.fixtures.length + 1,
    );
  }

  const refreshedAt = Timestamp.fromDate(refreshedPlan.createdAt);
  const batch = database.batch();
  for (const fixture of refreshedPlan.fixtures) {
    batch.set(
      database.collection("locations").doc(fixture.userID),
      locationDocumentData(fixture, refreshedAt),
    );
  }
  batch.update(manifestReference, {
    locationRefreshedAt: refreshedAt,
    updatedAt: refreshedAt,
  });
  await safeFirebaseCall(() => batch.commit());
  return operationSummary(
    "refresh",
    "refreshed",
    refreshedPlan,
    refreshedPlan.fixtures.length + 1,
  );
}

export async function cleanupTestFriendFixtures(
  database: Firestore,
  options: FixtureOwnerOptions,
): Promise<FixtureOperationSummary> {
  validateProjectID(options.projectID);
  validateOwnerUID(options.ownerUID);
  const ownerHash = hashText(options.ownerUID).slice(0, 12);
  const manifestReference = fixtureManifestReference(
    database,
    `owner-${ownerHash}`,
  );
  const manifestSnapshot = await safeFirebaseCall(() => manifestReference.get());
  if (!manifestSnapshot.exists) {
    return emptyCleanupSummary();
  }

  const parsed = parseFixtureManifest(
    manifestSnapshot.data(),
    options.projectID,
    options.ownerUID,
  );
  const fixtureReferences = fixtureTargetPaths(parsed.plan).map((path) =>
    database.doc(path)
  );
  const fixtureSnapshots = await safeFirebaseCall(() =>
    database.getAll(...fixtureReferences)
  );
  const pendingFixtures = parsed.plan.fixtures.filter(
    (fixture) => fixture.status === "pending",
  );
  const dispatchReferences = pendingFixtures.map((fixture) =>
    database
      .collection("notificationDispatches")
      .doc(notificationDispatchID(fixture.friendshipID, parsed.manifest.createdAt))
  );
  const dispatchSnapshots = dispatchReferences.length > 0
    ? await safeFirebaseCall(() => database.getAll(...dispatchReferences))
    : [];
  const deviceSnapshots = await safeFirebaseCall(() => Promise.all(
    dispatchReferences.map((reference) => reference.collection("devices").get()),
  ));
  const deviceReferences = deviceSnapshots.flatMap((snapshot) =>
    snapshot.docs.map((document) => document.ref)
  );
  if (deviceReferences.length > maximumNotificationDeviceTargets) {
    throw new FixtureToolError(
      "Le nettoyage a trouvé un nombre inattendu de cibles de notification.",
    );
  }

  const existingDocumentCount =
    fixtureSnapshots.filter((snapshot) => snapshot.exists).length +
    dispatchSnapshots.filter((snapshot) => snapshot.exists).length +
    deviceReferences.length +
    1;
  if (!options.apply) {
    return operationSummary(
      "cleanup",
      "would-clean",
      parsed.plan,
      existingDocumentCount,
    );
  }

  const friendshipReferences = parsed.plan.fixtures.map((fixture) =>
    database.collection("friendships").doc(fixture.friendshipID)
  );
  await deleteReferencesInChunks(database, friendshipReferences);

  const friendshipPaths = new Set(
    friendshipReferences.map((reference) => reference.path),
  );
  const remainingFixtureReferences = fixtureReferences.filter(
    (reference) => !friendshipPaths.has(reference.path),
  );
  await deleteReferencesInChunks(database, [
    ...remainingFixtureReferences,
    ...deviceReferences,
    ...dispatchReferences,
  ]);
  await safeFirebaseCall(() => manifestReference.delete());
  return operationSummary(
    "cleanup",
    "cleaned",
    parsed.plan,
    existingDocumentCount,
  );
}

function fixtureWrites(
  plan: FixturePlan,
): Array<{ path: string; data: DocumentData }> {
  const timestamp = Timestamp.fromDate(plan.createdAt);
  return plan.fixtures.flatMap((fixture) => {
    const friendshipData: DocumentData = {
      participants: [plan.ownerUID, fixture.userID].sort(),
      requestedBy: fixture.userID,
      status: fixture.status,
      createdAt: timestamp,
    };
    if (fixture.status === "accepted") {
      friendshipData.acceptedAt = timestamp;
    }
    return [
      {
        path: `users/${fixture.userID}`,
        data: {
          displayName: fixture.displayName,
          avatarID: fixture.avatarID,
          profileColorHex: fixture.profileColorHex,
          friendCode: fixture.friendCode,
          createdAt: timestamp,
          updatedAt: timestamp,
        },
      },
      {
        path: `friendCodes/${fixture.friendCode}`,
        data: {
          ownerId: fixture.userID,
          displayName: fixture.displayName,
          createdAt: timestamp,
        },
      },
      {
        path: `friendships/${fixture.friendshipID}`,
        data: friendshipData,
      },
      {
        path: `locations/${fixture.userID}`,
        data: locationDocumentData(fixture, timestamp),
      },
    ];
  });
}

function locationDocumentData(
  fixture: TestFriendFixture,
  timestamp: Timestamp,
): DocumentData {
  return {
    location: new GeoPoint(
      fixture.location.latitude,
      fixture.location.longitude,
    ),
    displayName: fixture.displayName,
    horizontalAccuracy: fixture.location.horizontalAccuracy,
    sampledAt: timestamp,
    updatedAt: timestamp,
    spotEnteredAt: Timestamp.fromDate(fixture.location.spotEnteredAt),
  };
}

function fixtureManifestReference(
  database: Firestore,
  manifestID: string,
): DocumentReference {
  return database.collection(manifestCollection).doc(manifestID);
}

async function deleteReferencesInChunks(
  database: Firestore,
  references: readonly DocumentReference[],
): Promise<void> {
  const uniqueReferences = [
    ...new Map(references.map((reference) => [reference.path, reference])).values(),
  ];
  for (let index = 0; index < uniqueReferences.length; index += writeBatchSize) {
    const batch = database.batch();
    for (const reference of uniqueReferences.slice(index, index + writeBatchSize)) {
      batch.delete(reference);
    }
    await safeFirebaseCall(() => batch.commit());
  }
}

function operationSummary(
  command: FixtureCommand,
  outcome: FixtureOperationSummary["outcome"],
  plan: FixturePlan,
  documentCount: number,
): FixtureOperationSummary {
  return {
    command,
    outcome,
    fixtureCount: plan.fixtures.length,
    acceptedCount: plan.acceptedCount,
    pendingCount: plan.pendingCount,
    locationCount: plan.fixtures.length,
    documentCount,
  };
}

function emptyCleanupSummary(): FixtureOperationSummary {
  return {
    command: "cleanup",
    outcome: "nothing-to-clean",
    fixtureCount: 0,
    acceptedCount: 0,
    pendingCount: 0,
    locationCount: 0,
    documentCount: 0,
  };
}

function fixtureDisplayName(index: number): string {
  const name = fixtureNames[index % fixtureNames.length] ?? fixtureNames[0];
  const cycle = Math.floor(index / fixtureNames.length);
  return cycle === 0 ? name : `${name} ${cycle + 1}`;
}

function deterministicFriendCode(ownerUID: string, index: number): string {
  const digest = createHash("sha256")
    .update(`${ownerUID}:friend-code:${index}`)
    .digest();
  return Array.from({ length: 12 }, (_, characterIndex) => {
    const value = digest[characterIndex] ?? 0;
    return friendCodeAlphabet[value % friendCodeAlphabet.length] ?? "A";
  }).join("");
}

function seoulLocation(
  ownerUID: string,
  index: number,
  sampledAt: Date,
): FixtureLocation {
  const base = seoulLocations[index % seoulLocations.length] ?? seoulLocations[0];
  if (!base) {
    throw new FixtureToolError("Le préréglage de Séoul est vide.");
  }
  const cycle = Math.floor(index / seoulLocations.length);
  const digest = createHash("sha256")
    .update(`${ownerUID}:seoul-location:${index}`)
    .digest();
  const latitudeOffset = cycle === 0
    ? 0
    : (((digest[0] ?? 127) / 255) - 0.5) * 0.0025 * cycle;
  const longitudeOffset = cycle === 0
    ? 0
    : (((digest[1] ?? 127) / 255) - 0.5) * 0.0030 * cycle;
  const minutesAtSpot = 10 + (index % 9) * 7;
  return {
    landmark: base.landmark,
    latitude: base.latitude + latitudeOffset,
    longitude: base.longitude + longitudeOffset,
    horizontalAccuracy: 12 + (index % 6) * 5,
    spotEnteredAt: new Date(sampledAt.getTime() - minutesAtSpot * 60_000),
  };
}

function validateCounts(acceptedCount: number, pendingCount: number): void {
  if (
    !Number.isInteger(acceptedCount) ||
    !Number.isInteger(pendingCount) ||
    acceptedCount < 0 ||
    pendingCount < 0 ||
    acceptedCount + pendingCount < 1 ||
    acceptedCount + pendingCount > maximumFixtureCount
  ) {
    throw new FixtureToolError(
      `Le nombre total d’amis fictifs doit être compris entre 1 et ${maximumFixtureCount}.`,
    );
  }
}

function validateProjectID(projectID: string): void {
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectID)) {
    throw new FixtureToolError("L’identifiant du projet Firebase est invalide.");
  }
}

function validateOwnerUID(ownerUID: string): void {
  if (
    ownerUID.length < 1 ||
    ownerUID.length > 128 ||
    ownerUID.includes("__")
  ) {
    throw new FixtureToolError("L’UID propriétaire est invalide.");
  }
}

function hashText(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function invalidManifestError(): FixtureToolError {
  return new FixtureToolError(
    "Le manifeste de fixtures est invalide. Aucune mutation n’a été effectuée.",
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function safeFirebaseCall<T>(operation: () => Promise<T>): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof FixtureToolError) {
      throw error;
    }
    const code = firebaseErrorCode(error);
    throw new FixtureToolError(
      code
        ? `L’opération Firebase a échoué (${code}).`
        : "L’opération Firebase a échoué.",
    );
  }
}

function firebaseErrorCode(error: unknown): string | null {
  if (!isRecord(error)) {
    return null;
  }
  const code = error.code;
  return typeof code === "string" || typeof code === "number"
    ? String(code).slice(0, 80)
    : null;
}
