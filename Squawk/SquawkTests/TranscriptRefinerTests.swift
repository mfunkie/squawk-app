import XCTest
@testable import Squawk

final class TranscriptRefinerTests: XCTestCase {
    private let refiner = TranscriptRefiner()

    // MARK: - Hallucination Guard Tests

    func testValidatedAcceptsReasonableCleanup() {
        let original = "um so like i went to the uh store and bought some some milk"
        let cleaned = "I went to the store and bought some milk."
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), cleaned)
    }

    func testValidatedRejectsEmptyResponse() {
        let original = "hello world"
        XCTAssertEqual(refiner.validated(cleaned: "", original: original), original)
    }

    func testValidatedRejectsTooLongResponse() {
        let original = "short input"
        let cleaned = String(repeating: "a", count: original.count * 2)
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsTooShortResponse() {
        let original = "this is a reasonably long transcript that should not be truncated to just a few characters"
        let cleaned = "hi"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsMarkdownCodeBlock() {
        let original = "some transcript text here"
        let cleaned = "```some transcript text here```"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsMarkdownBold() {
        let original = "some transcript text here"
        let cleaned = "some **transcript** text here"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsMarkdownHeading() {
        let original = "some transcript text here"
        let cleaned = "## Cleaned Transcript\nsome transcript text here"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsPreambleHereIs() {
        let original = "some transcript text here"
        let cleaned = "Here is the cleaned version: some transcript text here"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsPreambleIveCleaned() {
        let original = "some transcript text here"
        let cleaned = "I've cleaned up the transcript: some text here"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedRejectsPreambleCorrectedVersion() {
        let original = "some transcript text here"
        let cleaned = "Corrected version: some transcript text here"
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), original)
    }

    func testValidatedAcceptsSlightlyShorterResponse() {
        let original = "um so like i went to the store and bought some milk you know"
        let cleaned = "I went to the store and bought some milk."
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), cleaned)
    }

    func testValidatedAcceptsEqualLengthResponse() {
        let original = "i went to the store today"
        let cleaned = "I went to the store today."
        XCTAssertEqual(refiner.validated(cleaned: cleaned, original: original), cleaned)
    }

    // MARK: - OllamaError Tests

    func testOllamaErrorModelNotFoundDescription() {
        let error = OllamaError.modelNotFound("mistral")
        XCTAssertEqual(error.errorDescription, "Model 'mistral' not found. Run: ollama pull mistral")
    }

    func testOllamaErrorHttpErrorDescription() {
        let error = OllamaError.httpError(500)
        XCTAssertEqual(error.errorDescription, "Ollama returned HTTP 500")
    }

    func testOllamaErrorConnectionFailedDescription() {
        let error = OllamaError.connectionFailed
        XCTAssertEqual(error.errorDescription, "Cannot connect to Ollama at localhost:11434")
    }

    func testOllamaErrorInvalidResponseDescription() {
        let error = OllamaError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from Ollama")
    }
}
