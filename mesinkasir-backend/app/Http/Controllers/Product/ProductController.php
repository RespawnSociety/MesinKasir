<?php

namespace App\Http\Controllers\Product;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ProductController extends Controller
{
    private function ensureAdmin(Request $request): void
    {
        $role = $request->user()->role ?? null;
        if ($role !== 'admin') {
            abort(Response::HTTP_FORBIDDEN, 'Forbidden (admin only)');
        }
    }

    public function index(Request $request)
    {
        $query = Product::query()
            ->with(['category:id,name', 'stocks:id,name,active'])
            ->orderByDesc('id');

        if ($request->filled('search')) {
            $s = trim((string) $request->input('search'));
            $query->where('name', 'like', "%{$s}%");
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', (int) $request->input('category_id'));
        }

        if ($request->has('active')) {
            $query->where('active', (bool) $request->boolean('active'));
        }

        $perPage = (int) $request->input('per_page', 15);
        $perPage = max(1, min($perPage, 100));

        return response()->json([
            'message' => 'OK',
            'data' => $query->paginate($perPage),
        ]);
    }

    public function show(Request $request, Product $product)
    {
        return response()->json([
            'message' => 'OK',
            'data' => $product->load(['category:id,name', 'stocks:id,name,active']),
        ]);
    }

    public function store(Request $request)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'category_id' => ['required', 'integer', 'exists:product_categories,id'],
            'name' => ['required', 'string', 'max:120'],
            'price' => ['required', 'integer', 'min:0'],
            'qty' => ['nullable', 'integer', 'min:0'],
            'active' => ['nullable', 'boolean'],
        ]);

        $product = Product::create([
            'category_id' => (int) $validated['category_id'],
            'name' => $validated['name'],
            'price' => (int) $validated['price'],
            'qty' => (int) ($validated['qty'] ?? 0),
            'active' => (bool) ($validated['active'] ?? true),
        ]);

        return response()->json([
            'message' => 'Product created',
            'data' => $product->load(['category:id,name']),
        ], Response::HTTP_CREATED);
    }

    public function update(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'category_id' => ['sometimes', 'required', 'integer', 'exists:product_categories,id'],
            'name' => ['sometimes', 'required', 'string', 'max:120'],
            'price' => ['sometimes', 'required', 'integer', 'min:0'],
            'qty' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $product->fill($validated);

        if (array_key_exists('qty', $validated) && $validated['qty'] === null) {
            $product->qty = 0;
        }

        $product->save();

        return response()->json([
            'message' => 'Product updated',
            'data' => $product->load(['category:id,name']),
        ]);
    }

    public function destroy(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $product->delete();

        return response()->json([
            'message' => 'Product deleted',
        ]);
    }
}
