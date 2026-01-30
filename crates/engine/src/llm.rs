use serde::{Deserialize, Serialize};
use std::env;

use super::retrieve::Context;

/// Structured explanation result from the LLM
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExplainResult {
    pub term: String,
    pub meaning: String,
    pub usage: Vec<String>,
    pub examples: Vec<String>,
    pub pronunciation: String,
}

impl ExplainResult {
    /// Create a mock result for testing
    pub fn mock(term: &str) -> Self {
        Self {
            term: term.to_string(),
            meaning: format!("This is a mock explanation for '{}'.", term),
            usage: vec![
                format!("'{}' is commonly used in everyday conversation.", term),
                format!("You might hear '{}' in formal contexts.", term),
            ],
            examples: vec![
                format!("I often {} when working on projects.", term),
                format!("She decided to {} the task immediately.", term),
            ],
            pronunciation: format!("/{}/", term.to_lowercase()),
        }
    }
}

/// LLM client for generating explanations
pub struct LlmClient {
    api_key: Option<String>,
    base_url: String,
    model: String,
    mock_mode: bool,
}

impl LlmClient {
    /// Create a new LLM client from environment variables
    pub fn from_env() -> Self {
        let api_key = env::var("LLM_API_KEY").ok();
        let base_url =
            env::var("LLM_BASE_URL").unwrap_or_else(|_| "https://api.openai.com/v1".to_string());
        let model = env::var("LLM_MODEL").unwrap_or_else(|_| "gpt-4o-mini".to_string());

        let mock_mode = api_key.is_none();

        Self {
            api_key,
            base_url,
            model,
            mock_mode,
        }
    }

    /// Create a mock-only client for testing
    pub fn mock() -> Self {
        Self {
            api_key: None,
            base_url: String::new(),
            model: String::new(),
            mock_mode: true,
        }
    }

    /// Check if running in mock mode
    pub fn is_mock(&self) -> bool {
        self.mock_mode
    }

    /// Generate an explanation for the query with context
    pub async fn explain(&self, query: &str, context: &Context) -> Result<ExplainResult, String> {
        if self.mock_mode {
            return Ok(ExplainResult::mock(query));
        }

        self.call_api(query, context).await
    }

    async fn call_api(&self, query: &str, context: &Context) -> Result<ExplainResult, String> {
        let api_key = self.api_key.as_ref().ok_or("API key not configured")?;

        let system_prompt = r#"You are an English learning assistant. Your job is to explain English words, phrases, and expressions to help users learn.
Be concise and clear. Focus on practical usage.
Output ONLY valid JSON in this exact format:
{
  "term": "the word or phrase",
  "meaning": "clear definition",
  "usage": ["usage note 1", "usage note 2"],
  "examples": ["example sentence 1", "example sentence 2"],
  "pronunciation": "phonetic pronunciation"
}"#;

        let user_prompt = format!(
            "User question: {}\n\nRecent context:\n{}",
            query,
            context.combined_text()
        );

        let request_body = serde_json::json!({
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": 0.7,
            "response_format": {"type": "json_object"}
        });

        let client = reqwest::Client::new();
        let response = client
            .post(format!("{}/chat/completions", self.base_url))
            .header("Authorization", format!("Bearer {}", api_key))
            .header("Content-Type", "application/json")
            .json(&request_body)
            .send()
            .await
            .map_err(|e| format!("API request failed: {}", e))?;

        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await.unwrap_or_default();
            return Err(format!("API error {}: {}", status, text));
        }

        let response_json: serde_json::Value = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse response: {}", e))?;

        let content = response_json["choices"][0]["message"]["content"]
            .as_str()
            .ok_or("No content in response")?;

        serde_json::from_str(content).map_err(|e| format!("Failed to parse LLM output: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mock_result() {
        let result = ExplainResult::mock("ephemeral");
        assert_eq!(result.term, "ephemeral");
        assert!(!result.meaning.is_empty());
        assert!(!result.usage.is_empty());
        assert!(!result.examples.is_empty());
        assert!(!result.pronunciation.is_empty());
    }

    #[test]
    fn test_llm_client_mock_mode() {
        let client = LlmClient::mock();
        assert!(client.is_mock());
    }

    #[test]
    fn test_llm_client_from_env_no_key() {
        // Without LLM_API_KEY set, should default to mock mode
        std::env::remove_var("LLM_API_KEY");
        let client = LlmClient::from_env();
        assert!(client.is_mock());
    }

    #[tokio::test]
    async fn test_mock_explain() {
        let client = LlmClient::mock();
        let context = Context::new(vec![], vec![]);

        let result = client.explain("test", &context).await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap().term, "test");
    }
}
