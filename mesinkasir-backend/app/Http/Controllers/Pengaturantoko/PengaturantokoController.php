<?php

namespace App\Http\Controllers\Pengaturantoko;

use App\Http\Controllers\Controller;
use App\Models\ProductCategory;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class PengaturantokoController extends Controller
{
    private function ensureAdmin(Request $request): void
    {
        $role = $request->user()->role ?? null;
        if ($role !== 'admin') {
            abort(Response::HTTP_FORBIDDEN, 'Forbidden (admin only)');
        }
    }

    public function categories(Request $request)
    {
        $this->ensureAdmin($request);

        $activeOnly = $request->boolean('active_only', false);

        $q = ProductCategory::query()->orderBy('name');
        if ($activeOnly) {
            $q->where('active', true);
        }

        return response()->json(
            $q->get(['id', 'name', 'active', 'created_at', 'updated_at'])
        );
    }

    public function createCategory(Request $request)
    {
        $this->ensureAdmin($request);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60', 'unique:product_categories,name'],
        ]);

        $cat = ProductCategory::create([
            'name' => trim($data['name']),
            'active' => true,
        ]);

        return response()->json([
            'id' => $cat->id,
            'name' => $cat->name,
            'active' => (bool) $cat->active,
        ], 201);
    }

    public function setCategoryActive(Request $request, ProductCategory $category)
    {
        $this->ensureAdmin($request);

        $data = $request->validate([
            'active' => ['required', 'boolean'],
        ]);

        $category->active = (bool) $data['active'];
        $category->save();

        return response()->json([
            'id' => $category->id,
            'name' => $category->name,
            'active' => (bool) $category->active,
        ]);
    }

    public function deleteCategory(Request $request, ProductCategory $category)
    {
        $this->ensureAdmin($request);

        $category->delete();

        return response()->json([
            'message' => 'Kategori dihapus',
        ]);
    }

    public function updateCategory(Request $request, ProductCategory $category)
    {
        $this->ensureAdmin($request);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60', 'unique:product_categories,name,' . $category->id],
        ]);

        $category->name = trim($data['name']);
        $category->save();

        return response()->json([
            'id' => $category->id,
            'name' => $category->name,
            'active' => (bool) $category->active,
        ]);
    }
}
