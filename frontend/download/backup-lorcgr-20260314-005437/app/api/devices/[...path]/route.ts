import { NextRequest, NextResponse } from 'next/server';

// Backend Django URL
const BACKEND_URL = process.env.BACKEND_URL || 'http://45.71.242.131';

export async function GET(request: NextRequest) {
  return proxyRequest(request);
}

export async function POST(request: NextRequest) {
  return proxyRequest(request);
}

export async function PUT(request: NextRequest) {
  return proxyRequest(request);
}

export async function DELETE(request: NextRequest) {
  return proxyRequest(request);
}

export async function PATCH(request: NextRequest) {
  return proxyRequest(request);
}

async function proxyRequest(request: NextRequest) {
  try {
    // Get the path after /api
    const url = new URL(request.url);
    const path = url.pathname.replace('/api', '');
    const queryString = url.search;
    
    // Build the target URL
    const targetUrl = `${BACKEND_URL}${path}${queryString}`;
    
    console.log(`[Proxy] ${request.method} ${targetUrl}`);
    
    // Forward headers
    const headers = new Headers();
    request.headers.forEach((value, key) => {
      // Skip some headers that shouldn't be forwarded
      if (!['host', 'content-length', 'connection'].includes(key.toLowerCase())) {
        headers.set(key, value);
      }
    });
    
    // Get request body if present
    let body: string | undefined;
    if (request.body && ['POST', 'PUT', 'PATCH'].includes(request.method)) {
      body = await request.text();
    }
    
    // Make the request to the backend
    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body,
    });
    
    // Get response body
    const responseText = await response.text();
    
    // Create response with CORS headers
    const nextResponse = new NextResponse(responseText, {
      status: response.status,
      statusText: response.statusText,
    });
    
    // Copy response headers
    response.headers.forEach((value, key) => {
      nextResponse.headers.set(key, value);
    });
    
    // Add CORS headers
    nextResponse.headers.set('Access-Control-Allow-Origin', '*');
    nextResponse.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
    nextResponse.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    return nextResponse;
  } catch (error) {
    console.error('[Proxy] Error:', error);
    return NextResponse.json(
      { error: 'Proxy error', message: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

// Handle OPTIONS for CORS preflight
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
}
