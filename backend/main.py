from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pydantic_settings import BaseSettings
import databases
import sqlalchemy
import httpx
import os
from typing import List, Optional

class Settings(BaseSettings):
    DATABASE_URL: str
    # Using Groq as a free alternative
    LLM_API_KEY: str
    LLM_API_URL: str = "https://api.groq.com/openai/v1/chat/completions"
    LLM_MODEL: str = "llama-3.3-70b-versatile"
    SYSTEM_PROMPT: str = "You are a helpful DevOps assistant."

    class Config:
        env_file = ".env"

settings = Settings()

database = databases.Database(settings.DATABASE_URL)

metadata = sqlalchemy.MetaData()

prompts = sqlalchemy.Table(
    "prompts",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("prompt_text", sqlalchemy.String),
)

app = FastAPI()

class PromptResponse(BaseModel):
    id: int
    prompt_text: str

class LLMResponse(BaseModel):
    response: str

@app.on_event("startup")
async def startup():
    import asyncio
    retries = 5
    for i in range(retries):
        try:
            await database.connect()
            break
        except Exception as e:
            if i == retries - 1:
                raise e
            print(f"Database connection failed, retrying in 5 seconds... ({i+1}/{retries})")
            await asyncio.sleep(5)

@app.on_event("shutdown")
async def shutdown():
    await database.disconnect()

@app.get("/ids", response_model=List[int])
async def get_ids():
    query = prompts.select()
    results = await database.fetch_all(query)
    return [result["id"] for result in results]

@app.get("/prompt/{prompt_id}", response_model=PromptResponse)
async def get_prompt(prompt_id: int):
    query = prompts.select().where(prompts.c.id == prompt_id)
    result = await database.fetch_one(query)
    if not result:
        raise HTTPException(status_code=404, detail="Prompt not found")
    return {"id": result["id"], "prompt_text": result["prompt_text"]}

class TextPromptRequest(BaseModel):
    prompt_text: str

async def _call_llm(prompt_text: str) -> str:
    headers = {
        "Authorization": f"Bearer {settings.LLM_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": settings.LLM_MODEL,
        "messages": [
            {"role": "system", "content": settings.SYSTEM_PROMPT},
            {"role": "user", "content": prompt_text}
        ]
    }
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(settings.LLM_API_URL, json=payload, headers=headers, timeout=30.0)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=f"LLM API Error: {e.response.text}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/process-text", response_model=LLMResponse)
async def process_text(request: TextPromptRequest):
    llm_content = await _call_llm(request.prompt_text)
    return {"response": llm_content}

@app.post("/process/{prompt_id}", response_model=LLMResponse)
async def process_prompt(prompt_id: int):
    # 1. Fetch prompt from DB
    query = prompts.select().where(prompts.c.id == prompt_id)
    result = await database.fetch_one(query)
    
    if not result:
        raise HTTPException(status_code=404, detail="Prompt not found")
    
    prompt_text = result["prompt_text"]
    
    # 2. Call LLM API
    llm_content = await _call_llm(prompt_text)
    return {"response": llm_content}
