/**
 * AI Resume Analyzer - Firebase Cloud Functions
 * Node.js / TypeScript backend
 *
 * Deploy: firebase deploy --only functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();
const db = admin.firestore();

// ─── Gemini AI Client ─────────────────────────────────────────
const genAI = new GoogleGenerativeAI(functions.config().gemini.api_key);

// ─── Callable: Analyze Resume ─────────────────────────────────
exports.analyzeResume = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onCall(async (data, context) => {
    // Auth check
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { resumeText, jobId, resumeId } = data;

    if (!resumeText || !jobId || !resumeId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "resumeText, jobId, resumeId are required"
      );
    }

    // Fetch job details
    const jobDoc = await db.collection("jobs").doc(jobId).get();
    if (!jobDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Job not found");
    }
    const job = jobDoc.data();

    // Build prompt
    const prompt = buildAnalysisPrompt(resumeText, job);

    // Call Gemini
    const model = genAI.getGenerativeModel({
      model: "gemini-1.5-pro",
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 4096,
        responseMimeType: "application/json",
      },
    });

    const result = await model.generateContent(prompt);
    const responseText = result.response.text();

    let parsed;
    try {
      parsed = JSON.parse(responseText.replace(/```json|```/g, "").trim());
    } catch (e) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to parse AI response: ${e.message}`
      );
    }

    // Save to Firestore
    const analysisData = {
      userId: context.auth.uid,
      resumeId,
      jobId,
      jobTitle: job.title,
      matchScore: parsed.matchScore || 0,
      atsScore: parsed.atsScore || 0,
      projectScore: parsed.projectScore || 0,
      overallScore: parsed.overallScore || 0,
      missingSkills: parsed.missingSkills || [],
      strengths: parsed.strengths || [],
      weaknesses: parsed.weaknesses || [],
      projects: parsed.projects || [],
      finalRecommendation: parsed.finalRecommendation || "Fail",
      suggestions: parsed.suggestions || [],
      analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminDecision: null,
      adminNotes: null,
    };

    const docRef = await db.collection("analysis").add(analysisData);
    return { analysisId: docRef.id, ...analysisData };
  });

// ─── Callable: Rewrite Bullet Point ──────────────────────────
exports.rewriteBulletPoint = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }

  const { bulletPoint, jobTitle } = data;
  const model = genAI.getGenerativeModel({
    model: "gemini-1.5-pro",
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 512,
      responseMimeType: "application/json",
    },
  });

  const prompt = `Rewrite this resume bullet point to be stronger for a ${jobTitle} role.
Use strong action verbs, quantifiable impact, and be specific.
Original: ${bulletPoint}
Respond: {"rewrites": ["option1", "option2", "option3"]}`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();
  return JSON.parse(text.replace(/```json|```/g, "").trim());
});

// ─── Trigger: On Analysis Created → Send Notification ────────
exports.onAnalysisCreated = functions.firestore
  .document("analysis/{analysisId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    console.log(`New analysis created: ${context.params.analysisId}`);
    console.log(`User: ${data.userId}, Job: ${data.jobTitle}`);
    console.log(`Score: ${data.overallScore}, Recommendation: ${data.finalRecommendation}`);
    // Add push notification logic here if needed
    return null;
  });

// ─── Trigger: On Admin Decision → Log Audit ──────────────────
exports.onDecisionMade = functions.firestore
  .document("analysis/{analysisId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.adminDecision !== after.adminDecision && after.adminDecision) {
      await db.collection("audit_log").add({
        analysisId: context.params.analysisId,
        userId: after.userId,
        jobId: after.jobId,
        decision: after.adminDecision,
        notes: after.adminNotes || "",
        decidedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });

// ─── HTTP: Admin Stats Endpoint ───────────────────────────────
exports.getAdminStats = functions.https.onRequest(async (req, res) => {
  // Verify admin token
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  try {
    const token = authHeader.split(" ")[1];
    const decoded = await admin.auth().verifyIdToken(token);
    const userDoc = await db.collection("users").doc(decoded.uid).get();
    if (userDoc.data()?.role !== "admin") {
      res.status(403).json({ error: "Admin access required" });
      return;
    }

    const analyses = await db.collection("analysis").get();
    const data = analyses.docs.map((d) => d.data());

    const stats = {
      total: data.length,
      averageScore: data.length
        ? Math.round(data.reduce((s, a) => s + a.overallScore, 0) / data.length)
        : 0,
      recommendations: {
        pass: data.filter((a) => a.finalRecommendation === "Pass").length,
        fail: data.filter((a) => a.finalRecommendation === "Fail").length,
        highPotential: data.filter((a) => a.finalRecommendation === "High Potential").length,
      },
      decisions: {
        pass: data.filter((a) => a.adminDecision === "Pass").length,
        fail: data.filter((a) => a.adminDecision === "Fail").length,
        highPotential: data.filter((a) => a.adminDecision === "High Potential").length,
        pending: data.filter((a) => !a.adminDecision).length,
      },
    };

    res.json(stats);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Prompt Builder ───────────────────────────────────────────
function buildAnalysisPrompt(resumeText, job) {
  return `You are an expert technical recruiter and resume evaluator.
Analyze this resume against the job requirements with CONTEXTUAL understanding.
Do NOT rely purely on keyword matching. Infer skills from project context.

JOB: ${job.title}
DESCRIPTION: ${job.description}
REQUIRED SKILLS: ${(job.requiredSkills || []).join(", ")}
PREFERRED SKILLS: ${(job.preferredSkills || []).join(", ")}
MIN EXPERIENCE: ${job.minExperience || 0} years
REQUIRED PROJECT TYPES: ${(job.requiredProjectTypes || []).join(", ")}

RESUME:
${resumeText}

Respond ONLY with valid JSON:
{
  "matchScore": <0-100>,
  "atsScore": <0-100>,
  "projectScore": <0-100>,
  "overallScore": <0-100>,
  "missingSkills": ["skill1"],
  "strengths": ["specific strength with reasoning"],
  "weaknesses": ["specific weakness with context"],
  "projects": [
    {
      "name": "project name",
      "score": <0-100>,
      "techStack": "tech1, tech2",
      "complexity": "Low|Medium|High",
      "issues": ["issue"],
      "suggestions": ["improvement"]
    }
  ],
  "finalRecommendation": "Pass|Fail|High Potential",
  "suggestions": ["actionable improvement"]
}

finalRecommendation rules:
- "High Potential": overallScore >= 75 AND strong projects
- "Pass": overallScore >= 55 AND meets minimum requirements
- "Fail": overallScore < 55 OR critical skill gaps`;
}
