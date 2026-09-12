## ADDED Requirements

### Requirement: A final summary that cannot be read is asked for once more
Where the request that produces the word's final summary returns an answer that does not parse, the pipeline SHALL issue that request once more and SHALL use the second answer where it parses.

This stage alone is treated this way, because its value is what the reader sees: it is saved as the word's summary with nothing downstream judging it. Falling back to the answer's raw text used to mean the model had replied in prose, which reads acceptably as a summary. It now also covers an answer the response cap cut off before it closed, which does not, and which becomes reachable as soon as a provider gives up a schema constraint in order to get an answer at all.

This does not withdraw the raw-text fallback. The fallback remains the floor, and remains what is used when both answers are unreadable; what changes is that an unreadable answer is no longer saved without having been asked for a second time.

Exactly one further request SHALL be made. Where the second answer also does not parse, the first SHALL be kept: both are equally unreadable, one of them has to be shown, and a third generation on the slowest provider buys nothing.

Where the second request fails outright, the first answer SHALL be kept rather than the failure propagated. An answer in hand is worth more than the run that would be lost trying to improve on it.

This request is counted separately from the single retry that answers a failure. That retry is provoked by a request that raised or by a response the parser rejected; this one is provoked by a response the parser accepted into its fallback. Both can therefore apply to the same summary, and the stage SHALL be understood to issue up to three generations: two from the retry on failure, and one more when what the second produced could not be read.

An extraction that cannot be read SHALL NOT be re-requested this way. It is already marked unstructured, which keeps it out of the fact cache, and it costs the reader nothing beyond a re-extraction.

#### Scenario: A readable answer is taken as it stands
- **WHEN** the final summary request returns an answer that parses
- **THEN** exactly one request SHALL be made, and that answer SHALL be used

#### Scenario: An unreadable answer is replaced
- **WHEN** the final summary request returns an answer that does not parse, and a second request returns one that does
- **THEN** the second answer SHALL be used

#### Scenario: Two unreadable answers keep the first
- **WHEN** neither the first nor the second final summary answer parses
- **THEN** the first SHALL be used, and no third request SHALL be made

#### Scenario: A failed second request keeps the first answer
- **WHEN** the first final summary answer does not parse and the second request fails
- **THEN** the first answer SHALL be used, and the failure SHALL NOT end the run

#### Scenario: An unreadable extraction is not re-requested
- **WHEN** a Stage-1 fact extraction returns an answer that does not parse
- **THEN** it SHALL be marked as coming from the raw-text fallback, and no further request SHALL be made for it
