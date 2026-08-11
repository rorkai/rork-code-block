import RorkHighlighter

/// Represents the highlighting work produced for one source revision.
enum StreamingHighlightResult: Sendable {
  /// Supplies a complete snapshot after opening or rebuilding a session.
  case snapshot(HighlightSnapshot)

  /// Supplies one incremental edit and its corresponding highlight update.
  case update(
    previousSource: String,
    edit: SourceEdit,
    update: HighlightUpdate
  )

  /// Returns the complete snapshot carried by either result kind.
  var snapshot: HighlightSnapshot {
    switch self {
    case .snapshot(let snapshot):
      snapshot
    case .update(_, _, let update):
      update.snapshot
    }
  }
}

/// Reuses one Tree-sitter session across changing revisions of a code block.
actor StreamingHighlighter {
  /// Holds the mutable highlighting session for the current language.
  private var session: HighlightSession?

  /// Holds the source represented by ``session``.
  private var source: String?

  /// Holds the language represented by ``session``.
  private var language: CodeLanguage?

  /// Produces a complete snapshot or one incremental update for new source.
  ///
  /// Calls for one instance must remain serialized. ``CodeTextView`` provides
  /// that guarantee through a single coalescing processor task.
  ///
  /// - Parameters:
  ///   - newSource: The complete source requested by the view.
  ///   - newLanguage: The language used to parse the source.
  /// - Returns: The work required to render the requested revision.
  /// - Throws: ``HighlighterError`` when the language or source cannot be parsed.
  func highlight(
    _ newSource: String,
    as newLanguage: CodeLanguage
  ) async throws(HighlighterError) -> StreamingHighlightResult {
    guard
      let session,
      let source,
      language == newLanguage
    else {
      return try await openSession(
        source: newSource,
        language: newLanguage
      )
    }

    guard let edit = SourceEdit.difference(from: source, to: newSource) else {
      return .snapshot(try await session.snapshot())
    }

    do {
      let update = try await session.replaceCharacters(
        in: edit.range,
        with: edit.replacement
      )
      self.source = newSource
      return .update(
        previousSource: source,
        edit: edit,
        update: update
      )
    } catch {
      reset()
      throw error
    }
  }

  /// Opens a new incremental session for a source and language pair.
  ///
  /// - Parameters:
  ///   - source: The initial source represented by the session.
  ///   - language: The language used to parse the source.
  /// - Returns: A complete initial snapshot.
  /// - Throws: ``HighlighterError`` when the shared highlighter or session
  ///   cannot be created.
  private func openSession(
    source: String,
    language: CodeLanguage
  ) async throws(HighlighterError) -> StreamingHighlightResult {
    do {
      let highlighter = try await StandardHighlighterStore.shared.value()
      let session = try highlighter.makeSession(source, as: language)
      let snapshot = try await session.snapshot()

      self.session = session
      self.source = source
      self.language = language

      return .snapshot(snapshot)
    } catch {
      reset()
      throw error
    }
  }

  /// Discards state that may no longer match a failed session update.
  private func reset() {
    session = nil
    source = nil
    language = nil
  }
}

/// Creates the standard highlighter once and shares its immutable catalog.
actor StandardHighlighterStore {
  /// Provides the process-wide standard highlighter store.
  static let shared = StandardHighlighterStore()

  /// Caches either the standard highlighter or its deterministic load failure.
  private var cachedResult: Result<Highlighter, HighlighterError>?

  /// Returns the standard highlighter, loading it on this actor when needed.
  ///
  /// - Returns: The shared immutable highlighter.
  /// - Throws: ``HighlighterError`` when the bundled catalog cannot be loaded.
  func value() throws(HighlighterError) -> Highlighter {
    if let cachedResult {
      return try cachedResult.get()
    }

    let result: Result<Highlighter, HighlighterError>
    do {
      result = .success(try Highlighter())
    } catch {
      result = .failure(error)
    }

    cachedResult = result
    return try result.get()
  }
}
