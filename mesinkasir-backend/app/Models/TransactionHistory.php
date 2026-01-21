<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class TransactionHistory extends Model
{
    use HasFactory;

    protected $table = 'transaction_histories';

    protected $fillable = [
        'cashier_id',
        'items',
        'total_amount',
        'paid_amount',
        'change_amount',
        'paid_at',
        'source_transaction_id',
    ];

    protected $casts = [
        'items' => 'array',
        'paid_at' => 'datetime',
        'total_amount' => 'integer',
        'paid_amount' => 'integer',
        'change_amount' => 'integer',
        'source_transaction_id' => 'integer',
    ];

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function sourceTransaction(): BelongsTo
    {
        return $this->belongsTo(Transaction::class, 'source_transaction_id');
    }
}

