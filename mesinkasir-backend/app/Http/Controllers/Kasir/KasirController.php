<?php


namespace App\Http\Controllers\Kasir;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Symfony\Component\HttpFoundation\Response;

class KasirController extends Controller
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
        $this->ensureAdmin($request);

        $kasirs = User::query()
            ->where('role', 'kasir')
            ->orderBy('username')
            ->get(['id', 'username', 'active', 'created_at']);

        return response()->json($kasirs);
    }

    public function store(Request $request)
    {
        $this->ensureAdmin($request);

        $data = $request->validate([
            'username' => ['required', 'string', 'min:3', 'max:50', 'regex:/^[a-zA-Z0-9_]+$/', 'unique:users,username'],
            'pin' => ['required', 'string', 'min:6', 'max:64', 'regex:/^\S+$/'],
        ]);

        $adminEmail = $request->user()->email;

        if (!$adminEmail || !str_contains($adminEmail, '@')) {
            return response()->json(['message' => 'Email admin tidak valid'], 422);
        }

        $domain = explode('@', $adminEmail, 2)[1];
        $username = trim($data['username']);
        $kasirEmail = strtolower($username) . '@' . $domain;

        if (User::where('email', $kasirEmail)->exists()) {
            return response()->json(['message' => 'Email kasir sudah dipakai'], 422);
        }

        $kasir = User::create([
            'username' => $username,
            'name'     => $username,
            'email'    => $kasirEmail,
            'password' => Hash::make($data['pin']),
            'pin_hash' => Hash::make($data['pin']),
            'role'     => 'kasir',
            'active'   => true,
        ]);

        return response()->json([
            'message' => 'Akun kasir berhasil dibuat',
            'kasir' => [
                'id' => $kasir->id,
                'username' => $kasir->username,
                'email' => $kasir->email,
                'active' => (bool) $kasir->active,
            ],
        ], 201);
    }

    public function setActive(Request $request, string $username)
    {
        $this->ensureAdmin($request);

        $data = $request->validate([
            'active' => ['required', 'boolean'],
        ]);

        $kasir = User::query()
            ->where('role', 'kasir')
            ->where('username', $username)
            ->firstOrFail();

        $kasir->active = (bool) $data['active'];
        $kasir->save();

        return response()->json([
            'message' => 'Status kasir diperbarui',
            'username' => $kasir->username,
            'active' => (bool) $kasir->active,
        ]);
    }

    public function resetPin(Request $request, string $username)
    {
        $this->ensureAdmin($request);

        $data = $request->validate([
            'pin' => ['required', 'string', 'min:6', 'max:64'],
        ]);

        $kasir = User::query()
            ->where('role', 'kasir')
            ->where('username', $username)
            ->firstOrFail();

        $kasir->pin_hash = Hash::make($data['pin']);
        $kasir->password = Hash::make($data['pin']);
        $kasir->save();

        return response()->json([
            'message' => 'Password kasir berhasil diubah',
            'username' => $kasir->username,
        ]);
    }

    public function destroy(Request $request, string $username)
    {
        $this->ensureAdmin($request);

        $kasir = User::query()
            ->where('role', 'kasir')
            ->where('username', $username)
            ->firstOrFail();

        $kasir->delete();

        return response()->json([
            'message' => 'Kasir berhasil dihapus',
            'username' => $username,
        ]);
    }
}
