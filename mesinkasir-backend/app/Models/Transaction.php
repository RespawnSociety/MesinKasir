<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Transaction extends Model
{
    use HasFactory;

    protected $table = 'transactions';

    protected $fillable = [
        'cashier_id',
        'items',
        'total_amount',
        'paid_amount',
        'change_amount',
        'paid_at',
    ];

    protected $casts = [
        'items' => 'array',
        'paid_at' => 'datetime',
        'total_amount' => 'integer',
        'paid_amount' => 'integer',
        'change_amount' => 'integer',
    ];

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }
}
