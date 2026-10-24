# Supplementary T-001 evidence table under approved v2

Every row retains its original checkpoint state. `observed-defect` links actual named Red; `new-admission-contract` binds the missing-admission control plus its own Green without claiming an individual Red; `reused-already-correct` links actual retrospective old/current boundary executions.

| Runtime | Exact case | Category | Original checkpoint | Evidence |
|---|---|---|---|---|
| bash | CONTROL::prior-own-stage-NEEDS_WORK | reused-already-correct | unchanged PASS | baseline-bash.json + regression-bash.json |
| bash | CONTROL::persisted-A-real-verifier | reused-already-correct | unchanged PASS | baseline-bash.json + regression-bash.json |
| bash | CONTROL::valid-interrupted-admission | observed-defect | real Red exit90 | red-bash.log |
| bash | TEST-050-F01::schema::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F01::schema::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F01::schema::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F01::schema::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F01::schema::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F01::schema::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050-F02::feature::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F02::feature::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F02::feature::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F02::feature::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F02::feature::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F02::feature::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050-F03::source::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F03::source::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F03::source::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F04::source.attempt::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F04::source.attempt::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F04::source.attempt::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F04::source.attempt::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F04::source.attempt::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F05::source.round::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F05::source.round::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F05::source.round::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F05::source.round::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F05::source.round::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F06::target::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F06::target::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F06::target::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F07::target.attempt::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F07::target.attempt::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F07::target.attempt::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F07::target.attempt::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F07::target.attempt::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F08::target.round::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F08::target.round::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F08::target.round::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F08::target.round::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F08::target.round::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F09::authorization::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F09::authorization::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F09::authorization::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F10::previous_contract::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F10::previous_contract::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F10::previous_contract::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F11::interrupted_precheck::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F11::interrupted_precheck::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F11::interrupted_precheck::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F12::pinned_inputs::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F12::pinned_inputs::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F12::pinned_inputs::object | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F13::interrupted_artifacts::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F13::interrupted_artifacts::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F13::interrupted_artifacts::object | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F14::reviewer_a::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F14::reviewer_a::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F14::reviewer_a::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F15::reviewer_a.invocation::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F15::reviewer_a.invocation::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F15::reviewer_a.invocation::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F16::reviewer_a.sequence::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F16::reviewer_a.sequence::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F16::reviewer_a.sequence::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F16::reviewer_a.sequence::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F16::reviewer_a.sequence::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-F17::reviewer_a.stage::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F17::reviewer_a.stage::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F17::reviewer_a.stage::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F17::reviewer_a.stage::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F17::reviewer_a.stage::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F17::reviewer_a.stage::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050-F18::reviewer_a.role::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F18::reviewer_a.role::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F18::reviewer_a.role::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F18::reviewer_a.role::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F18::reviewer_a.role::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F18::reviewer_a.role::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050-F19::reviewer_a.run_id::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F19::reviewer_a.run_id::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F19::reviewer_a.run_id::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F19::reviewer_a.run_id::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F19::reviewer_a.run_id::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F19::reviewer_a.run_id::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050-F20::reviewer_a.host_session_id::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F20::reviewer_a.host_session_id::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F20::reviewer_a.host_session_id::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F20::reviewer_a.host_session_id::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F20::reviewer_a.host_session_id::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F20::reviewer_a.host_session_id::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050-F21::reviewer_a.record_sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F21::reviewer_a.record_sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051-F21::reviewer_a.record_sha256::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F21::reviewer_a.record_sha256::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F21::reviewer_a.record_sha256::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-051-F21::reviewer_a.record_sha256::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-01.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-01.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-01.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-01.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H01::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H01::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H01::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H01::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H01::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H01::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P01::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-02.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-02.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-02.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-02.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H02::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H02::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H02::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H02::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H02::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H02::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P02::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-03.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-03.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-03.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-03.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H03::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H03::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H03::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H03::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H03::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H03::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P03::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-04.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-04.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-04.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-04.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H04::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H04::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H04::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H04::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H04::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H04::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P04::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-05.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-05.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-05.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-05.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H05::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H05::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H05::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H05::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H05::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H05::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P05::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-06.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-06.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-06.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-06.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H06::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H06::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H06::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H06::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H06::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H06::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P06::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-07.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-07.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-07.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-07.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H07::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H07::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H07::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H07::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H07::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H07::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P07::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-08.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-08.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-08.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-08.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H08::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H08::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H08::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H08::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H08::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H08::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P08::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-09.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-09.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-09.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-09.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H09::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H09::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H09::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H09::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H09::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H09::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P09::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-10.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-10.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-10.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-10.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H10::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H10::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H10::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H10::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H10::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H10::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P10::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-11.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-11.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-11.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-11.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H11::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H11::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H11::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H11::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H11::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H11::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P11::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-12.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-12.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-12.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-12.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H12::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H12::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H12::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H12::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H12::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H12::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P12::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-13.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-13.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-13.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-13.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H13::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H13::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H13::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H13::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H13::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H13::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P13::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-14.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-14.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050::reference-14.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-051::reference-14.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H14::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H14::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H14::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H14::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H14::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057-H14::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-083-P14::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-057::reviewer_a.record_sha256::uppercase | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-057::reviewer_a.record_sha256::nonhex | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-057::reviewer_a.record_sha256::short | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-052::root::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::root::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::root::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::root::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::source::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::source::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::source::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::source::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::target::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::target::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::target::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::target::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::reviewer_a::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::reviewer_a::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::reviewer_a::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::reviewer_a::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::authorization::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::authorization::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::authorization::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::authorization::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::previous_contract::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::previous_contract::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::previous_contract::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::previous_contract::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_precheck::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_precheck::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_precheck::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_precheck::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::pinned_inputs.3::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::pinned_inputs.3::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.3::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.3::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::pinned_inputs.1::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::pinned_inputs.1::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.1::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.1::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::pinned_inputs.2::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::pinned_inputs.2::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.2::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.2::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::pinned_inputs.0::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::pinned_inputs.0::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.0::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::pinned_inputs.0::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_artifacts.1::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_artifacts.1::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.1::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.1::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_artifacts.4::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_artifacts.4::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.4::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.4::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_artifacts.3::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_artifacts.3::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.3::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.3::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_artifacts.2::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_artifacts.2::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.2::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.2::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_artifacts.5::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_artifacts.5::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.5::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.5::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::interrupted_artifacts.0::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::interrupted_artifacts.0::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.0::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::interrupted_artifacts.0::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-052::reviewer_a.invocation::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-055::reviewer_a.invocation::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::reviewer_a.invocation::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-053::reviewer_a.invocation::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-044::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-054::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-045::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-046::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-047::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-048::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-049::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-009::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-010::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-011::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-056::record-encoding::utf-16 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-056::record-encoding::utf-16-be | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-056::record-encoding::utf-8-sig | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-035::authorization-UTF16 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-056::malformed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-012::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-013::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-014::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-015::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-058::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-059::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-060::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-061::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-017::semantic | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-018::semantic | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-019::semantic | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-021::semantic | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-023::semantic | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-033::semantic | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-034::semantic | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-082::semantic | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-016::missing | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-020::missing | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-035::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-026::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-027::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-028::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-029::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-030::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-031::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-032::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-062::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-062::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-063::missing | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-063::altered | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | TEST-064::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-064::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-065::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-065::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-066::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-066::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-067::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-067::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-069::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-070::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-071::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-072::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-073::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-074::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-068::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-068::extra | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-068::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A01::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A01::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A01::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A02::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A02::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A02::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A03::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A03::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A03::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A04::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A04::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A04::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A05::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A05::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A05::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A06::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A06::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A06::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A07::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A07::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A07::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A08::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A08::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-050-A08::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-079::later-valid-record | reused-already-correct | NOT_RUN | baseline-bash.json + regression-bash.json |
| bash | CONTROL::canonical-binding-key-order-and-whitespace | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| bash | TEST-043::canonical-binding-unicode-escaped-equivalent | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-043::canonical-binding-extra-final-newline | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-043::canonical-binding-omit-target | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-043::canonical-binding-reorder-array | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-017::prior-contract::schema | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::stage | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::feature | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::attempt | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::round | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::warningCount | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::requirements_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::acceptance_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-017::prior-contract::investigation_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::schema | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::attempt | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::round | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::generated_at | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::reviewer_a_fail_count | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::reviewer_a_pass_count | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary::reviewer_a_skip_count | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary-check::id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary-check::result | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-021::summary-check::severity | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-a::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-a::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-a::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-a::manifest-path | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-a::manifest-sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-a::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-a::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-a::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-a::verdict | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-b::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-b::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-b::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-b::manifest-path | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-reviewer-b::manifest-sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-b::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-b::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-b::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-022::prior-raw-b::verdict | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::schema | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::stage | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::feature | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::attempt | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::round | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::reviewer_a_run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::reviewer_b_run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::reviewer_a_host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::reviewer_b_host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::warningCount | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::verdict | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::finding_counts.critical | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::finding_counts.major | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-023::integrated-verdict::finding_counts.minor | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-062::rebound-precheck-boolean::schema | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::stage | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::feature | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::spec_review_status_field | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::requirements_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::acceptance_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::investigation_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::calibration_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::rebound-precheck-boolean::input_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::schema | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::stage | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::feature | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::attempt | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::round | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::spec_review_status_field | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::requirements_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::acceptance_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::investigation_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::calibration_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-062::precheck::input_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-063::raw::schema | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw::stage | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw::verdict | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-034::substantive-check::result | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-034::substantive-check::id | observed-defect | not present at original checkpoint | red-raw-shape-bash.log |
| bash | TEST-034::substantive-check::severity | observed-defect | not present at original checkpoint | red-raw-shape-bash.log |
| bash | TEST-034::substantive-check::finding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-034::diagnostic-boolean::id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-034::diagnostic-boolean::result | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-034::diagnostic-boolean::severity | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-034::domain-skip-without-unreadability | observed-defect | not present at original checkpoint | red-raw-shape-bash.log |
| bash | TEST-064::host::review_execution_started::None | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-064::host::review_execution_started::false | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-064::host::sessionId::wrong | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-064::host::threadId::wrong | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-064::host-boolean::sessionId | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-064::host-boolean::threadId | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-063::raw-boolean::schema | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw-boolean::stage | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw-boolean::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw-boolean::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw-boolean::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-063::raw-boolean::verdict | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation-boolean-feature | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-064::host-nonstandard-JSON-overflow | observed-defect | not present at original checkpoint | red-overflow-bash.log |
| bash | TEST-064::host-nonstandard-JSON-NaN | observed-defect | not present at original checkpoint | red-host-json-bash.log |
| bash | TEST-064::host-nonstandard-JSON-Infinity | observed-defect | not present at original checkpoint | red-host-json-bash.log |
| bash | TEST-066::invocation::schema | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::input_mode | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::fallback_mode | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::read_only | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::feature | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::identity_ledger_path | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::identity_ledger_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::sequence | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::stage | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-066::invocation::previous_record_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-076::invocation-input::path | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-076::invocation-input::sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-065::receipt::record_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-065::receipt::sequence | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-065::receipt::previous_record_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-065::receipt::pre_append_tip_sequence | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-065::receipt::identity_unique | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-030::final-report-verdict | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-069::persisted::sequence | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-072::persisted::stage | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-073::persisted::role | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-070::persisted::run_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-071::persisted::host_session_id | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-074::persisted::record_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-075::persisted::previous_record_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-076::persisted::allowed_inputs_sha256 | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-075::broken-prefix | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-024::B-invocation | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-080::canonical-B-omitted-source-pin | observed-defect | not present at original checkpoint | red-ambiguous-b-bash.log |
| bash | TEST-080::canonical-B-misdeclared-feature | observed-defect | not present at original checkpoint | red-ambiguous-b-bash.log |
| bash | TEST-080::aliased-B-source-dot | observed-defect | not present at original checkpoint | red-independent-path-bash.log |
| bash | TEST-080::aliased-B-source-historical-absolute | observed-defect | not present at original checkpoint | red-independent-path-bash.log |
| bash | TEST-080::aliased-B-source-historical-relative | observed-defect | not present at original checkpoint | red-independent-path-bash.log |
| bash | TEST-080::aliased-B-source-missing-precheck | observed-defect | not present at original checkpoint | red-path-attribution-bash.log |
| bash | TEST-080::aliased-B-source-miscased-precheck | observed-defect | not present at original checkpoint | red-path-attribution-bash.log |
| bash | TEST-080::aliased-B-source-newline-precheck | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-080::aliased-B-source-selfdeclared-domain | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-025::orphan-bound-B | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-080::orphan-unbound-B | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-080::unbound-correlated-B | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-077::duplicate-persisted-identity | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-078::partial-run-collision | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-078::partial-session-collision | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-079::later-valid-other-round-reviewer | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-079::later-unrelated-B-shared-calibration-and-host | reused-already-correct | not present at original checkpoint | baseline-bash.json + regression-bash.json |
| bash | TEST-079::later-unrelated-domain-real-verifier | observed-defect | not present at original checkpoint | red-domain-compat-bash.log |
| bash | TEST-008::source-not-latest | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-036::authorization-raw-hash | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-037::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-038::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-039::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-040::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-043::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| bash | TEST-081::prior-contract-raw-hash | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | CONTROL::prior-own-stage-NEEDS_WORK | reused-already-correct | unchanged PASS | baseline-powershell.json + regression-powershell.json |
| powershell | CONTROL::persisted-A-real-verifier | reused-already-correct | unchanged PASS | baseline-powershell.json + regression-powershell.json |
| powershell | CONTROL::valid-interrupted-admission | observed-defect | real Red exit90 | red-powershell.log |
| powershell | TEST-050-F01::schema::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F01::schema::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F01::schema::boolean-true | observed-defect | not present at original checkpoint | red-schema-type-powershell.log |
| powershell | TEST-051-F01::schema::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F01::schema::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F01::schema::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050-F02::feature::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F02::feature::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F02::feature::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F02::feature::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F02::feature::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F02::feature::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050-F03::source::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F03::source::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F03::source::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F04::source.attempt::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F04::source.attempt::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F04::source.attempt::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F04::source.attempt::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F04::source.attempt::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F05::source.round::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F05::source.round::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F05::source.round::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F05::source.round::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F05::source.round::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F06::target::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F06::target::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F06::target::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F07::target.attempt::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F07::target.attempt::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F07::target.attempt::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F07::target.attempt::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F07::target.attempt::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F08::target.round::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F08::target.round::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F08::target.round::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F08::target.round::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F08::target.round::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F09::authorization::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F09::authorization::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F09::authorization::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F10::previous_contract::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F10::previous_contract::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F10::previous_contract::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F11::interrupted_precheck::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F11::interrupted_precheck::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F11::interrupted_precheck::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F12::pinned_inputs::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F12::pinned_inputs::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F12::pinned_inputs::object | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F13::interrupted_artifacts::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F13::interrupted_artifacts::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F13::interrupted_artifacts::object | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F14::reviewer_a::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F14::reviewer_a::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F14::reviewer_a::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F15::reviewer_a.invocation::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F15::reviewer_a.invocation::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F15::reviewer_a.invocation::array | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F16::reviewer_a.sequence::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F16::reviewer_a.sequence::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F16::reviewer_a.sequence::string | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F16::reviewer_a.sequence::boolean | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F16::reviewer_a.sequence::fractional | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-F17::reviewer_a.stage::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F17::reviewer_a.stage::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F17::reviewer_a.stage::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F17::reviewer_a.stage::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F17::reviewer_a.stage::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F17::reviewer_a.stage::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050-F18::reviewer_a.role::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F18::reviewer_a.role::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F18::reviewer_a.role::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F18::reviewer_a.role::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F18::reviewer_a.role::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F18::reviewer_a.role::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050-F19::reviewer_a.run_id::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F19::reviewer_a.run_id::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F19::reviewer_a.run_id::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F19::reviewer_a.run_id::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F19::reviewer_a.run_id::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F19::reviewer_a.run_id::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050-F20::reviewer_a.host_session_id::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F20::reviewer_a.host_session_id::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F20::reviewer_a.host_session_id::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F20::reviewer_a.host_session_id::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F20::reviewer_a.host_session_id::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F20::reviewer_a.host_session_id::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050-F21::reviewer_a.record_sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F21::reviewer_a.record_sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051-F21::reviewer_a.record_sha256::boolean-true | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F21::reviewer_a.record_sha256::array-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F21::reviewer_a.record_sha256::object-value | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-051-F21::reviewer_a.record_sha256::number | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-01.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-01.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-01.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-01.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H01::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H01::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H01::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H01::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H01::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H01::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P01::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-02.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-02.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-02.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-02.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H02::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H02::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H02::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H02::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H02::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H02::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P02::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-03.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-03.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-03.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-03.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H03::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H03::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H03::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H03::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H03::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H03::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P03::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-04.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-04.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-04.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-04.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H04::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H04::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H04::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H04::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H04::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H04::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P04::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-05.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-05.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-05.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-05.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H05::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H05::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H05::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H05::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H05::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H05::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P05::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-06.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-06.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-06.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-06.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H06::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H06::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H06::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H06::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H06::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H06::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P06::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-07.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-07.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-07.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-07.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H07::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H07::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H07::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H07::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H07::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H07::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P07::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-08.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-08.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-08.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-08.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H08::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H08::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H08::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H08::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H08::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H08::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P08::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-09.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-09.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-09.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-09.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H09::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H09::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H09::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H09::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H09::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H09::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P09::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-10.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-10.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-10.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-10.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H10::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H10::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H10::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H10::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H10::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H10::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P10::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-11.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-11.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-11.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-11.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H11::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H11::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H11::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H11::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H11::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H11::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P11::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-12.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-12.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-12.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-12.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H12::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H12::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H12::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H12::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H12::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H12::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P12::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-13.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-13.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-13.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-13.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H13::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H13::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H13::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H13::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H13::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H13::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P13::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-14.path::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-14.path::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050::reference-14.sha256::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-051::reference-14.sha256::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H14::null | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H14::uppercase | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H14::nonhex | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H14::short | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H14::incorrect | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057-H14::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::empty | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::absolute | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::drive | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::traversal | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::dot | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::empty-segment | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::backslash | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::tab | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::newline | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::nul | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::control | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-083-P14::del | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-057::reviewer_a.record_sha256::uppercase | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-057::reviewer_a.record_sha256::nonhex | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-057::reviewer_a.record_sha256::short | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-052::root::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::root::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::root::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::root::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::source::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::source::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::source::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::source::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::target::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::target::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::target::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::target::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::reviewer_a::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::reviewer_a::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::reviewer_a::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::reviewer_a::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::authorization::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::authorization::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::authorization::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::authorization::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::previous_contract::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::previous_contract::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::previous_contract::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::previous_contract::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_precheck::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_precheck::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_precheck::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_precheck::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::pinned_inputs.3::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::pinned_inputs.3::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.3::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.3::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::pinned_inputs.1::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::pinned_inputs.1::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.1::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.1::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::pinned_inputs.2::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::pinned_inputs.2::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.2::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.2::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::pinned_inputs.0::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::pinned_inputs.0::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.0::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::pinned_inputs.0::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_artifacts.1::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_artifacts.1::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.1::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.1::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_artifacts.4::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_artifacts.4::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.4::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.4::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_artifacts.3::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_artifacts.3::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.3::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.3::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_artifacts.2::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_artifacts.2::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.2::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.2::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_artifacts.5::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_artifacts.5::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.5::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.5::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::interrupted_artifacts.0::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::interrupted_artifacts.0::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.0::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::interrupted_artifacts.0::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-052::reviewer_a.invocation::unknown | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-055::reviewer_a.invocation::uppercase-key | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::reviewer_a.invocation::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-053::reviewer_a.invocation::escaped-duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-044::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-054::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-045::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-046::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-047::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-048::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-049::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-009::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-010::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-011::value | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-056::record-encoding::utf-16 | observed-defect | not present at original checkpoint | red-encoding-powershell.log |
| powershell | TEST-056::record-encoding::utf-16-be | observed-defect | not present at original checkpoint | red-encoding-powershell.log |
| powershell | TEST-056::record-encoding::utf-8-sig | observed-defect | not present at original checkpoint | red-encoding-powershell.log |
| powershell | TEST-035::authorization-UTF16 | observed-defect | not present at original checkpoint | red-authorization-encoding-powershell.log |
| powershell | TEST-056::malformed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-012::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-013::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-014::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-015::status | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-058::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-059::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-060::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-061::changed-live | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-017::semantic | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-018::semantic | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-019::semantic | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::semantic | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::semantic | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-033::semantic | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-034::semantic | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-082::semantic | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-016::missing | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-020::missing | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-035::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-026::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-027::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-028::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-029::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-030::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-031::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-032::extra-source | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-062::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-062::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-063::missing | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::altered | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-064::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-064::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-065::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-065::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-066::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-066::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-067::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-067::altered | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-069::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-070::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-071::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-072::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-073::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-074::identity | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-068::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-068::extra | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-068::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A01::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A01::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A01::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A02::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A02::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A02::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A03::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A03::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A03::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A04::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A04::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A04::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A05::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A05::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A05::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A06::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A06::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A06::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A07::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A07::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A07::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A08::missing | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A08::duplicate | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-050-A08::changed | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-079::later-valid-record | reused-already-correct | NOT_RUN | baseline-powershell.json + regression-powershell.json |
| powershell | CONTROL::canonical-binding-key-order-and-whitespace | new-admission-contract | NOT_RUN | missing-admission control + individual reviewed log |
| powershell | TEST-043::canonical-binding-unicode-escaped-equivalent | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-043::canonical-binding-extra-final-newline | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-043::canonical-binding-omit-target | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-043::canonical-binding-reorder-array | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-017::prior-contract::schema | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::stage | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::feature | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::attempt | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::round | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::warningCount | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::requirements_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::acceptance_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-017::prior-contract::investigation_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::schema | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::attempt | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::round | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::generated_at | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::reviewer_a_fail_count | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::reviewer_a_pass_count | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary::reviewer_a_skip_count | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary-check::id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary-check::result | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-021::summary-check::severity | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-a::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-a::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-a::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-a::manifest-path | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-a::manifest-sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-a::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-a::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-a::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-a::verdict | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-b::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-b::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-b::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-b::manifest-path | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-reviewer-b::manifest-sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-b::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-b::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-b::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-022::prior-raw-b::verdict | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::schema | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::stage | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::feature | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::attempt | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::round | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::reviewer_a_run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::reviewer_b_run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::reviewer_a_host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::reviewer_b_host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::warningCount | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::verdict | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::finding_counts.critical | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::finding_counts.major | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-023::integrated-verdict::finding_counts.minor | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-062::rebound-precheck-boolean::schema | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::stage | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::feature | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::spec_review_status_field | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::requirements_sha256 | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::acceptance_sha256 | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::investigation_sha256 | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::calibration_sha256 | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::rebound-precheck-boolean::input_sha256 | observed-defect | not present at original checkpoint | red-precheck-type-powershell.log |
| powershell | TEST-062::precheck::schema | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::stage | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::feature | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::attempt | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::round | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::spec_review_status_field | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::requirements_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::acceptance_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::investigation_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::calibration_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-062::precheck::input_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-063::raw::schema | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw::stage | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw::verdict | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-034::substantive-check::result | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-034::substantive-check::id | observed-defect | not present at original checkpoint | red-raw-shape-powershell.log |
| powershell | TEST-034::substantive-check::severity | observed-defect | not present at original checkpoint | red-raw-shape-powershell.log |
| powershell | TEST-034::substantive-check::finding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-034::diagnostic-boolean::id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-034::diagnostic-boolean::result | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-034::diagnostic-boolean::severity | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-034::domain-skip-without-unreadability | observed-defect | not present at original checkpoint | red-raw-shape-powershell.log |
| powershell | TEST-064::host::review_execution_started::None | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-064::host::review_execution_started::false | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-064::host::sessionId::wrong | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-064::host::threadId::wrong | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-064::host-boolean::sessionId | observed-defect | not present at original checkpoint | red-boolean-sweep-powershell.log |
| powershell | TEST-064::host-boolean::threadId | observed-defect | not present at original checkpoint | red-boolean-sweep-powershell.log |
| powershell | TEST-063::raw-boolean::schema | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw-boolean::stage | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw-boolean::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw-boolean::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw-boolean::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-063::raw-boolean::verdict | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation-boolean-feature | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-064::host-nonstandard-JSON-overflow | observed-defect | not present at original checkpoint | red-overflow-powershell.log |
| powershell | TEST-064::host-nonstandard-JSON-NaN | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-064::host-nonstandard-JSON-Infinity | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-066::invocation::schema | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::input_mode | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::fallback_mode | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::read_only | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::feature | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::identity_ledger_path | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::identity_ledger_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::sequence | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::stage | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-066::invocation::previous_record_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-076::invocation-input::path | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-076::invocation-input::sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-065::receipt::record_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-065::receipt::sequence | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-065::receipt::previous_record_sha256 | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-065::receipt::pre_append_tip_sequence | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-065::receipt::identity_unique | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-030::final-report-verdict | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-069::persisted::sequence | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-072::persisted::stage | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-073::persisted::role | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-070::persisted::run_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-071::persisted::host_session_id | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-074::persisted::record_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-075::persisted::previous_record_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-076::persisted::allowed_inputs_sha256 | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-075::broken-prefix | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-024::B-invocation | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-080::canonical-B-omitted-source-pin | observed-defect | not present at original checkpoint | red-ambiguous-b-powershell.log |
| powershell | TEST-080::canonical-B-misdeclared-feature | observed-defect | not present at original checkpoint | red-ambiguous-b-powershell.log |
| powershell | TEST-080::aliased-B-source-dot | observed-defect | not present at original checkpoint | red-independent-path-powershell.log |
| powershell | TEST-080::aliased-B-source-historical-absolute | observed-defect | not present at original checkpoint | red-independent-path-powershell.log |
| powershell | TEST-080::aliased-B-source-historical-relative | observed-defect | not present at original checkpoint | red-independent-path-powershell.log |
| powershell | TEST-080::aliased-B-source-missing-precheck | observed-defect | not present at original checkpoint | red-path-attribution-powershell.log |
| powershell | TEST-080::aliased-B-source-miscased-precheck | observed-defect | not present at original checkpoint | red-path-attribution-powershell.log |
| powershell | TEST-080::aliased-B-source-newline-precheck | observed-defect | not present at original checkpoint | red-path-attribution-powershell.log |
| powershell | TEST-080::aliased-B-source-selfdeclared-domain | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-025::orphan-bound-B | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-080::orphan-unbound-B | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-080::unbound-correlated-B | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-077::duplicate-persisted-identity | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-078::partial-run-collision | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-078::partial-session-collision | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-079::later-valid-other-round-reviewer | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-079::later-unrelated-B-shared-calibration-and-host | reused-already-correct | not present at original checkpoint | baseline-powershell.json + regression-powershell.json |
| powershell | TEST-079::later-unrelated-domain-real-verifier | observed-defect | not present at original checkpoint | red-domain-compat-powershell.log |
| powershell | TEST-008::source-not-latest | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-036::authorization-raw-hash | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-037::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-038::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-039::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-040::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-043::binding | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
| powershell | TEST-081::prior-contract-raw-hash | new-admission-contract | not present at original checkpoint | missing-admission control + individual reviewed log |
